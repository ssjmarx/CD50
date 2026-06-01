# SwoopDirector
# Moves entities along a generated curve path via checkpoints with staggered entry
# Writes move_direction + move_distance to entity blackboard each frame
# Emits zero-arg swoop_complete on game bus when each entity finishes

@tool
class_name SwoopDirector extends CDGameComponent

# --- exports ---

# groups containing entities that should swoop
@export var swooping_groups: Array[StringName] = [&"swooping"]
# when true, entity must be in ALL listed groups (intersection); false = any group (union)
@export var require_all: bool = false
# destination point for the curve end
@export var target: Vector2 = Vector2.ZERO:
	set(v):
		target = v
		if is_node_ready():
			queue_redraw()

# CDCurve resource that generates the Curve2D path
@export var curve: CDCurve:
	set(v):
		_disconnect_curve()
		curve = v
		_connect_curve()
		if is_node_ready():
			queue_redraw()

# spacing between entities in the entry line
@export_group("Line Formation")
@export var slot_spacing: float = 30.0

@export_group("Blackboard Keys")
# key for writing movement direction to entity blackboard (Vector2)
@export var direction_key: StringName = &"move_direction"
# key for writing remaining distance to entity blackboard (float)
@export var distance_key: StringName = &"move_distance"
# key for writing completed entity to game blackboard (CDEntity)
@export var completed_entity_key: StringName = &"swoop_completed_entity"

# game bus signals that trigger swoop start
@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"spawning_complete"]

# game bus signals emitted when each entity finishes its swoop path
@export_group("Emit Signals")
@export var on_swoop_complete: Array[StringName] = [&"swoop_complete"]

# distance threshold to consider a checkpoint reached
@export_group("Checkpoints")
@export var checkpoint_spacing: float = 30.0
@export var arrival_threshold: float = 8.0

# editor preview drawing settings
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

# --- state ---

# the generated Curve2D for the current swoop
var _curve: Curve2D
# total baked length of the curve
var _curve_length: float = 0.0
# evenly-spaced world positions along the curve
var _checkpoints: PackedVector2Array = []
# current checkpoint index per entity
var _checkpoint_indices: Dictionary = {}
# entry delay remaining per entity (staggered line formation)
var _entry_delays: Dictionary = {}
# entities currently swooping
var _slots: Array[CDEntity] = []

# --- lifecycle ---

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

# connect curve resource change signal
func _enter_tree() -> void:
	_connect_curve()

# disconnect curve resource change signal
func _exit_tree() -> void:
	_disconnect_curve()

# --- curve resource management ---

func _disconnect_curve() -> void:
	if curve and curve.changed.is_connected(_request_redraw):
		curve.changed.disconnect(_request_redraw)

func _connect_curve() -> void:
	if curve and not curve.changed.is_connected(_request_redraw):
		curve.changed.connect(_request_redraw)

func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

# connect trigger signals to game bus
func _on_initialize() -> void:
	for sig in trigger_signals:
		game.bus_connect(sig, _on_trigger)

# --- editor preview ---

func _draw() -> void:
	if not Engine.is_editor_hint() or not curve:
		return
	
	var preview: Curve2D = curve.generate_curve(Vector2.ZERO, target - global_position)
	var points: PackedVector2Array = preview.get_baked_points()
	if points.size() < 2:
		return
	
	draw_polyline(points, preview_color, preview_width, true)

# --- checkpoint generation ---

func _generate_checkpoints() -> PackedVector2Array:
	var points: PackedVector2Array = []
	var dist := 0.0
	while dist <= _curve_length:
		points.append(_curve.sample_baked(dist))
		dist += checkpoint_spacing
	
	# ensure the final point is included
	var last := _curve.sample_baked(_curve_length)
	if points.size() == 0 or points[points.size() - 1].distance_to(last) > 1.0:
		points.append(last)
	return points

# --- swoop trigger ---

# gather swooping entities, generate curve and checkpoints, assign staggered delays
func _on_trigger() -> void:
	var entities: Array[CDEntity] = _gather_entities()
	if entities.is_empty():
		return
	
	# generate the curve from director position to target
	if curve:
		_curve = curve.generate_curve(global_position, target)
		_curve_length = _curve.get_baked_length()
	else:
		return
	
	# build checkpoints along the curve
	_checkpoints = _generate_checkpoints()
	
	# assign each entity a slot with staggered entry delay
	_slots.clear()
	_checkpoint_indices.clear()
	_entry_delays.clear()
	var slot_index := 0
	for entity in entities:
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			continue
		_slots.append(entity)
		_checkpoint_indices[entity] = 0
		_entry_delays[entity] = slot_index * slot_spacing
		slot_index += 1
	
	set_physics_process(true)

# --- entity gathering ---

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

# --- processing ---

# write move_direction + move_distance to each entity's blackboard each frame
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# stop processing if no active swoop
	if not _curve or _slots.is_empty():
		set_physics_process(false)
		return
	
	var completed: Array = []
	
	for entity: CDEntity in _slots:
		# skip invalid or inactive entities
		if not is_instance_valid(entity) or entity.state != CDEnums.EntityState.ACTIVE:
			completed.append(entity)
			continue
		
		# wait for entry delay (staggered line formation)
		if _entry_delays[entity] > 0.0:
			_entry_delays[entity] -= delta
			continue
		
		var idx: int = _checkpoint_indices[entity]
		
		# check if entity has passed all checkpoints
		if idx >= _checkpoints.size():
			completed.append(entity)
			continue
		
		# calculate direction and distance to current checkpoint
		var target_pos: Vector2 = _checkpoints[idx]
		var dist_to_target := entity.global_position.distance_to(target_pos)
		
		if dist_to_target <= arrival_threshold:
			# advance to next checkpoint
			_checkpoint_indices[entity] = idx + 1
			
			# check if that was the last checkpoint
			if _checkpoint_indices[entity] >= _checkpoints.size():
				completed.append(entity)
				continue
			
			# write next checkpoint data to blackboard
			var next_pos: Vector2 = _checkpoints[_checkpoint_indices[entity]]
			var next_dist := entity.global_position.distance_to(next_pos)
			entity.blackboard[direction_key] = entity.global_position.direction_to(next_pos)
			entity.blackboard[distance_key] = next_dist
		else:
			# write current checkpoint data to blackboard
			entity.blackboard[direction_key] = entity.global_position.direction_to(target_pos)
			entity.blackboard[distance_key] = dist_to_target
	
	# clean up completed entities
	for entity in completed:
		_slots.erase(entity)
		_checkpoint_indices.erase(entity)
		_entry_delays.erase(entity)
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			# write completed entity to game blackboard for downstream consumers
			game.blackboard[completed_entity_key] = entity
			for sig in on_swoop_complete:
				game.bus_emit(sig)
	
	# stop processing when all entities have finished
	if _slots.is_empty():
		set_physics_process(false)

# --- reset ---

func reset() -> void:
	if curve:
		curve.reset()
	_curve = null
	_curve_length = 0.0
	_checkpoints.clear()
	_checkpoint_indices.clear()
	_entry_delays.clear()
	_slots.clear()
	set_physics_process(false)