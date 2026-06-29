## SwoopDirector
## Moves entities along a curve using virtual "ghost" target points for deterministic spacing
## Emits swoop_complete on game bus when each entity finishes

@tool
class_name SwoopDirector extends CDGameComponent

## --- exports ---

@export var swooping_groups: Array[StringName] = [&"swooping"]
@export var require_all: bool = false
@export var target: Vector2 = Vector2.ZERO:
	set(v):
		target = v
		if is_node_ready():
			queue_redraw()

@export var curve: CDCurve:
	set(v):
		_disconnect_curve()
		curve = v
		_connect_curve()
		if is_node_ready():
			queue_redraw()

@export_group("Movement")
@export var swoop_speed: float = 200.0
@export var formation_offset: float = 16.0

@export_group("Lanes")
## number of side-by-side lanes (1 = single file, 2 = pairs, 3 = triples)
@export var lane_count: int = 1:
	set(v):
		lane_count = maxi(1, v)
## pixel spacing between lanes
@export var lane_spacing: float = 16.0

@export_group("Blackboard Keys")
@export var direction_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"
@export var completed_entity_key: StringName = &"swoop_completed_entity"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"spawning_complete"]

@export_group("Emit Signals")
@export var on_swoop_complete: Array[StringName] = [&"swoop_complete"]

@export_group("Preview")
@export var show_preview: bool = true:
	set(v):
		show_preview = v
		if is_node_ready():
			queue_redraw()
@export var preview_color: Color = Color.CYAN:
	set(v):
		preview_color = v
		if is_node_ready():
			queue_redraw()
@export var preview_width: float = 1.0:
	set(v):
		preview_width = v
		if is_node_ready():
			queue_redraw()

## --- state ---

var _curve: Curve2D
var _curve_length: float = 0.0
var _ghost_offsets: Dictionary = {} # {CDEntity: float} — offset along curve in pixels
var _entity_lanes: Dictionary = {}  # {CDEntity: float} — lane index (-0.5, +0.5, etc.)
var _lane_axis: Vector2 = Vector2.RIGHT # fixed perpendicular axis for lane offsets
var _slots: Array[CDEntity] = []
var _pending: Array[CDEntity] = []
var _pixels_per_frame: float = 0.0
var _entry_delay_frames: int = 1
var _frame_counter: int = 0
var _release_countdown: int = 0

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

## enter tree
func _enter_tree() -> void:
	_connect_curve()

## exit tree — disconnect the curve, then let the base auto-disconnect tracked bus signals
func _exit_tree() -> void:
	_disconnect_curve()
	super._exit_tree()

## --- curve resource management ---

## disconnect curve
func _disconnect_curve() -> void:
	if curve and curve.changed.is_connected(_request_redraw):
		curve.changed.disconnect(_request_redraw)

## connect curve
func _connect_curve() -> void:
	if curve and not curve.changed.is_connected(_request_redraw):
		curve.changed.connect(_request_redraw)

## request redraw
func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

## --- initialization ---

## on initialize
func _on_initialize() -> void:
	connect_all(trigger_signals, _on_trigger)

## --- editor preview ---

## draw
func _draw() -> void:
	if not show_preview or not Engine.is_editor_hint() or not curve:
		return
	
	var preview: Curve2D = curve.generate_curve(Vector2.ZERO, target - global_position)
	var points: PackedVector2Array = preview.get_baked_points()
	if points.size() < 2:
		return
	
	draw_polyline(points, preview_color, preview_width, true)

## --- swoop trigger ---

## gather swooping entities, generate curve, calculate frame constants, release first entity
func _on_trigger() -> void:
	var entities: Array[CDEntity] = _gather_entities()
	if entities.is_empty():
		return
	
	## generate the curve from director position to target
	if not curve:
		return
	_curve = curve.generate_curve(global_position, target)
	_curve_length = _curve.get_baked_length()
	## compute fixed lane axis from initial tangent direction
	if _curve_length > 0.0:
		var sample_dist := minf(10.0, _curve_length)
		var start_tangent := (_curve.sample_baked(sample_dist) - _curve.sample_baked(0.0)).normalized()
		_lane_axis = Vector2(-start_tangent.y, start_tangent.x)
	else:
		_lane_axis = Vector2.RIGHT
	
	var fps: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	_pixels_per_frame = swoop_speed / fps
	_entry_delay_frames = maxi(1, roundi(formation_offset * fps / swoop_speed))
	
	## clear all state
	_slots.clear()
	_ghost_offsets.clear()
	_entity_lanes.clear()
	_pending.clear()
	_frame_counter = 0
	_release_countdown = 0
	
	## filter to valid active entities
	var valid: Array[CDEntity] = []
	for entity in entities:
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			valid.append(entity)
	
	if valid.is_empty():
		return
	
	## release entities in lane groups (lane_count at a time, then delay)
	_release_lane_group(valid)
	
	set_physics_process(true)

## release a group of lane_count entities simultaneously, assigning each to a lane
func _release_lane_group(valid: Array[CDEntity]) -> void:
	var count := mini(lane_count, valid.size())
	for i in count:
		var entity := valid[i]
		var lane_value: float = _get_lane_value(i, lane_count)
		_entity_lanes[entity] = lane_value
		_release_entity(entity)
	## remaining entities go to pending — they'll be released in lane groups too
	for i in range(count, valid.size()):
		_pending.append(valid[i])

## compute perpendicular lane value for lane index within a group
func _get_lane_value(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return (float(index) - (float(count) - 1.0) / 2.0)

## release an entity onto the curve with ghost offset at 0
func _release_entity(entity: CDEntity) -> void:
	_slots.append(entity)
	_ghost_offsets[entity] = 0.0
	_release_countdown = _entry_delay_frames
	if _curve_length > 0.0:
		var lane: float = _entity_lanes.get(entity, 0.0)
		var offset_pos := _apply_lane_offset(0.0, lane)
		entity.blackboard[direction_key] = entity.global_position.direction_to(offset_pos)
		entity.blackboard[distance_key] = entity.global_position.distance_to(offset_pos)

## compute ghost position with fixed-axis lane offset
func _apply_lane_offset(offset: float, lane: float) -> Vector2:
	return _curve.sample_baked(offset) + _lane_axis * lane * lane_spacing

## --- entity gathering ---

## gather entities
## (require_all mode intersects groups manually; the ANY branch delegates to
## the registry's dedup helper. active filtering happens later in _on_trigger.)
func _gather_entities() -> Array[CDEntity]:
	if require_all and swooping_groups.size() > 1:
		var entities: Array[CDEntity] = []
		var first_group: StringName = swooping_groups[0]
		for entity in game.group_registry.get_group(first_group):
			if not is_instance_valid(entity):
				continue
			var in_all := true
			for i in range(1, swooping_groups.size()):
				if not entity.is_in_group(swooping_groups[i]):
					in_all = false
					break
			if in_all:
				entities.append(entity)
		return entities
	return game.group_registry.get_groups_union(swooping_groups, false)

## --- processing ---

## advance ghost offsets, release pending entities, write targets to entity blackboards
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not _curve or (_slots.is_empty() and _pending.is_empty()):
		set_physics_process(false)
		return
	
	if not _pending.is_empty():
		_pending = _pending.filter(func(e): return is_instance_valid(e))
		_release_countdown -= 1
		if _release_countdown <= 0:
			## release a lane group from pending
			var count := mini(lane_count, _pending.size())
			for i in count:
				var next = _pending.pop_front()
				if is_instance_valid(next) and next.state == CDEnums.EntityState.ACTIVE:
					var lane_value: float = _get_lane_value(i, lane_count)
					_entity_lanes[next] = lane_value
					_release_entity(next)
			_release_countdown = _entry_delay_frames
	
	_frame_counter += 1
	
	var completed: Array = []
	
	for entity: CDEntity in _slots:
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			completed.append(entity)
			continue
		
		var offset: float = _ghost_offsets[entity]
		offset += _pixels_per_frame
		
		if offset >= _curve_length:
			completed.append(entity)
			continue
		
		_ghost_offsets[entity] = offset
		var lane: float = _entity_lanes.get(entity, 0.0)
		var ghost_pos: Vector2 = _apply_lane_offset(offset, lane)
		entity.blackboard[direction_key] = entity.global_position.direction_to(ghost_pos)
		entity.blackboard[distance_key] = entity.global_position.distance_to(ghost_pos)
	
	## clean up completed entities
	for entity in completed:
		_slots.erase(entity)
		_ghost_offsets.erase(entity)
		_entity_lanes.erase(entity)
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			game.blackboard[completed_entity_key] = entity
			for sig in on_swoop_complete:
				game.bus_emit_from(sig, entity)
	
	if _slots.is_empty() and _pending.is_empty():
		set_physics_process(false)

## --- reset ---

## reset
func reset() -> void:
	if curve:
		curve.reset()
	_curve = null
	_curve_length = 0.0
	_ghost_offsets.clear()
	_lane_axis = Vector2.RIGHT
	_entity_lanes.clear()
	_slots.clear()
	_pending.clear()
	_pixels_per_frame = 0.0
	_entry_delay_frames = 1
	_frame_counter = 0
	_release_countdown = 0
	set_physics_process(false)
