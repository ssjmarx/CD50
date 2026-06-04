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

@export_group("Blackboard Keys")
@export var direction_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"
@export var completed_entity_key: StringName = &"swoop_completed_entity"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"spawning_complete"]

@export_group("Emit Signals")
@export var on_swoop_complete: Array[StringName] = [&"swoop_complete"]

@export_group("Preview")
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

## exit tree
func _exit_tree() -> void:
	_disconnect_curve()

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
	for sig in trigger_signals:
		game.bus_connect(sig, _on_trigger)

## --- editor preview ---

## draw
func _draw() -> void:
	if not Engine.is_editor_hint() or not curve:
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
	if curve:
		_curve = curve.generate_curve(global_position, target)
		_curve_length = _curve.get_baked_length()
	else:
		return
	
	var fps: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	_pixels_per_frame = swoop_speed / fps
	_entry_delay_frames = maxi(1, roundi(formation_offset * fps / swoop_speed))
	
	## clear all state
	_slots.clear()
	_ghost_offsets.clear()
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
	
	_release_entity(valid[0])
	for i in range(1, valid.size()):
		_pending.append(valid[i])
	
	set_physics_process(true)

## release an entity onto the curve with ghost offset at 0
func _release_entity(entity: CDEntity) -> void:
	_slots.append(entity)
	_ghost_offsets[entity] = 0.0
	_release_countdown = _entry_delay_frames
	if _curve_length > 0.0:
		var start_pos: Vector2 = _curve.sample_baked(0.0)
		entity.blackboard[direction_key] = entity.global_position.direction_to(start_pos)
		entity.blackboard[distance_key] = entity.global_position.distance_to(start_pos)

## --- entity gathering ---

## gather entities
func _gather_entities() -> Array[CDEntity]:
	var entities: Array[CDEntity] = []
	
	if require_all and swooping_groups.size() > 1:
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
	else:
		var seen: Dictionary = {}
		for group_name in swooping_groups:
			for entity in game.group_registry.get_group(group_name):
				if not seen.has(entity):
					seen[entity] = true
					entities.append(entity)
	
	return entities

## --- processing ---

## advance ghost offsets, release pending entities, write targets to entity blackboards
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not _curve or (_slots.is_empty() and _pending.is_empty()):
		set_physics_process(false)
		return
	
	if not _pending.is_empty():
		_release_countdown -= 1
		if _release_countdown <= 0:
			var next: CDEntity = _pending.pop_front()
			if is_instance_valid(next) and next.state == CDEnums.EntityState.ACTIVE:
				_release_entity(next)
			else:
				_release_countdown = 0
	
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
		var ghost_pos: Vector2 = _curve.sample_baked(offset)
		entity.blackboard[direction_key] = entity.global_position.direction_to(ghost_pos)
		entity.blackboard[distance_key] = entity.global_position.distance_to(ghost_pos)
	
	## clean up completed entities
	for entity in completed:
		_slots.erase(entity)
		_ghost_offsets.erase(entity)
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
	_slots.clear()
	_pending.clear()
	_pixels_per_frame = 0.0
	_entry_delay_frames = 1
	_frame_counter = 0
	_release_countdown = 0
	set_physics_process(false)