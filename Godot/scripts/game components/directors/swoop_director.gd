# SwoopDirector
# Moves entities along a generated curve path via checkpoints with staggered entry
# Emits swoop_complete on the game bus when each entity finishes its path

@tool
class_name SwoopDirector extends CDGameComponent

# --- exports ---

# group name for entities that should swoop
@export var swooping_group: StringName = &"swooping"
# game bus signal that triggers swoop start
@export var trigger_signal: StringName = &"wave_start"
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
# speed at which entities travel toward checkpoints
@export var entry_speed: float = 200.0

# distance between generated checkpoints along the curve
@export_group("Checkpoints")
@export var checkpoint_spacing: float = 30.0
# distance threshold to consider a checkpoint reached
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

# disconnect from curve resource change notifications
func _disconnect_curve() -> void:
	if curve and curve.changed.is_connected(_request_redraw):
		curve.changed.disconnect(_request_redraw)

# connect to curve resource change notifications
func _connect_curve() -> void:
	if curve and not curve.changed.is_connected(_request_redraw):
		curve.changed.connect(_request_redraw)

# request a redraw when curve resource changes
func _request_redraw() -> void:
	if is_inside_tree():
		queue_redraw()

# connect trigger signal to game bus
func _on_initialize() -> void:
	if trigger_signal != &"":
		game.bus_connect(trigger_signal, _on_trigger)

# --- editor preview ---

# draw the curve as a polyline in the editor
func _draw() -> void:
	if not Engine.is_editor_hint() or not curve:
		return
	
	var preview: Curve2D = curve.generate_curve(Vector2.ZERO, target - global_position)
	var points: PackedVector2Array = preview.get_baked_points()
	if points.size() < 2:
		return
	
	draw_polyline(points, preview_color, preview_width, true)

# --- checkpoint generation ---

# generate evenly-spaced checkpoints along the baked curve
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
func _on_trigger(_wave_number: int = 0) -> void:
	var entities := game.group_registry.get_group(swooping_group)
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
		_entry_delays[entity] = slot_index * slot_spacing / entry_speed
		slot_index += 1
	
	set_physics_process(true)

# --- processing ---

# advance each entity along its checkpoint path each frame
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
		
		# move toward current checkpoint
		var target_pos: Vector2 = _checkpoints[idx]
		var dist_to_target := entity.global_position.distance_to(target_pos)
		
		if dist_to_target <= arrival_threshold:
			# advance to next checkpoint
			_checkpoint_indices[entity] = idx + 1
			
			# check if that was the last checkpoint
			if _checkpoint_indices[entity] >= _checkpoints.size():
				completed.append(entity)
				continue
			
			# command entity toward next checkpoint
			entity.ensure_signal("move_to")
			entity.emit_signal("move_to", _checkpoints[_checkpoint_indices[entity]])
		else:
			# command entity toward current checkpoint
			entity.ensure_signal("move_to")
			entity.emit_signal("move_to", target_pos)
	
	# clean up completed entities
	for entity in completed:
		_slots.erase(entity)
		_checkpoint_indices.erase(entity)
		_entry_delays.erase(entity)
		if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
			game.bus_emit("swoop_complete", [entity])
	
	# stop processing when all entities have finished
	if _slots.is_empty():
		set_physics_process(false)

# --- reset ---

# clear all swoop state for game restart
func reset() -> void:
	_curve = null
	_curve_length = 0.0
	_checkpoints.clear()
	_checkpoint_indices.clear()
	_entry_delays.clear()
	_slots.clear()
	set_physics_process(false)