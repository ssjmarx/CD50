## AISwoopBrain
## Entity-level brain that follows a CDCurve path via checkpoints
## Triggered on by entity bus signal, one-shot path, emits complete when done

@tool
class_name AISwoopBrain extends CDEntityComponent

## --- exports ---

## CDCurve resource that generates the Curve2D path
@export var curve: CDCurve:
	set(v):
		_disconnect_curve()
		curve = v
		_connect_curve()
		if is_node_ready():
			queue_redraw()

## direction from entity to curve end point
@export var target_direction: Vector2 = Vector2.DOWN

## how far the curve extends from the entity
@export var target_distance: float = 400.0

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Checkpoints")
## distance between generated checkpoints along the curve
@export var checkpoint_spacing: float = 30.0
## distance to consider a checkpoint reached
@export var arrival_threshold: float = 8.0

@export_group("Loop Mode")
## when true, regenerate curve from current position when the end of the path is reached
@export var loop: bool = false

@export_group("Listen Signals")
## entity bus signals that start the swoop
@export var start_signals: Array[StringName] = [&"begin_swoop"]
## entity bus signals that abort the swoop early
@export var stop_signals: Array[StringName] = []
## entity bus signals that immediately stop and restart the swoop from the current position
@export var reset_signals: Array[StringName] = []

@export_group("Emit Signals")
## entity bus signals emitted when swoop path completes or is aborted
@export var complete_signals: Array[StringName] = [&"swoop_complete"]

@export_group("Preview")
## color for the editor preview curve
@export var preview_color: Color = Color.CYAN:
	set(v):
		preview_color = v
		if is_node_ready():
			queue_redraw()
## line width for the editor preview curve
@export var preview_width: float = 1.0:
	set(v):
		preview_width = v
		if is_node_ready():
			queue_redraw()

## --- state ---

## the generated Curve2D for the current swoop
var _curve2d: Curve2D
## total baked length of the curve
var _curve_length: float = 0.0
## evenly-spaced world positions along the curve
var _checkpoints: PackedVector2Array = []
## current checkpoint index
var _current_index: int = 0
## whether currently executing a swoop
var _is_swooping: bool = false

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()
	_connect_curve()

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

## --- editor preview ---

## draw the curve as a polyline in the editor
func _draw() -> void:
	if not Engine.is_editor_hint() or not curve:
		return

	var start := Vector2.ZERO
	var target := start + target_direction.normalized() * target_distance
	var preview: Curve2D = curve.generate_curve(start, target)
	var points: PackedVector2Array = preview.get_baked_points()
	if points.size() < 2:
		return

	draw_polyline(points, preview_color, preview_width, true)

## animate preview redraws in editor
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

## connect start/stop triggers
func _on_initialize() -> void:
	for sig in start_signals:
		self.bus_connect(sig, _on_start_swoop)

	for sig in stop_signals:
		self.bus_connect(sig, _on_stop_swoop)
		
	for sig in reset_signals:
		self.bus_connect(sig, _on_reset_swoop)

## --- swoop triggers ---

## generate the curve path and begin following checkpoints
func _on_start_swoop() -> void:
	if _is_swooping:
		return

	if not curve:
		return

	## generate curve from entity position to target point
	var start := entity.global_position
	var target := start + target_direction.normalized() * target_distance
	_curve2d = curve.generate_curve(start, target)
	_curve_length = _curve2d.get_baked_length()

	_checkpoints = _generate_checkpoints()
	if _checkpoints.is_empty():
		return

	_current_index = 0
	_is_swooping = true
	set_physics_process(true)

## abort the swoop early (e.g. return to formation signal)
func _on_stop_swoop() -> void:
	if not _is_swooping:
		return
	_end_swoop()

## cleanly stop and restart the swoop from current position
func _on_reset_swoop() -> void:
	_cleanup_swoop()
	_on_start_swoop()

## --- checkpoint generation ---

## generate evenly-spaced checkpoints along the baked curve
func _generate_checkpoints() -> PackedVector2Array:
	var points: PackedVector2Array = []
	var dist := 0.0
	while dist <= _curve_length:
		points.append(_curve2d.sample_baked(dist))
		dist += checkpoint_spacing

	## ensure the final point is included
	var last := _curve2d.sample_baked(_curve_length)
	if points.size() == 0 or points[points.size() - 1].distance_to(last) > 1.0:
		points.append(last)
	return points

## --- processing ---

## advance along checkpoint path each frame
func _physics_process(_delta: float) -> void:
	if not _is_swooping or _checkpoints.is_empty():
		return

	var target_pos := _checkpoints[_current_index]
	var to_checkpoint = target_pos - entity.global_position
	
	entity.blackboard[move_key] = to_checkpoint.normalized()
	entity.blackboard[distance_key] = to_checkpoint.length()

	## advance to next checkpoint when close enough
	if entity.global_position.distance_to(target_pos) < arrival_threshold:
		_current_index += 1
		if _current_index >= _checkpoints.size():
			## loop internally if enabled, otherwise end the swoop
			if loop and is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
				_regenerate_curve()
			else:
				_end_swoop()

## regenerate the curve from the entity's current position
func _regenerate_curve() -> void:
	if not curve:
		return
	var start := entity.global_position
	var target := start + target_direction.normalized() * target_distance
	_curve2d = curve.generate_curve(start, target)
	_curve_length = _curve2d.get_baked_length()
	_checkpoints = _generate_checkpoints()
	_current_index = 0

## internal cleanup logic used by both stop and reset
func _cleanup_swoop() -> void:
	_is_swooping = false
	_checkpoints.clear()
	_current_index = 0
	_curve2d = null
	_curve_length = 0.0
	
	## Clear intent from the blackboard so legs stop moving the entity
	entity.blackboard[move_key] = Vector2.ZERO
	entity.blackboard[distance_key] = 0.0
	
	set_physics_process(false)

## end the swoop, clear intent, and emit complete signals
func _end_swoop() -> void:
	_cleanup_swoop()

	for sig in complete_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## clean up swoop state on entity deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_swooping = false
	_checkpoints.clear()
	_current_index = 0
	_curve2d = null
	_curve_length = 0.0
	
	for sig in start_signals:
		self.bus_disconnect(sig, _on_start_swoop)
	for sig in stop_signals:
		self.bus_disconnect(sig, _on_stop_swoop)
	for sig in reset_signals:
		self.bus_disconnect(sig, _on_reset_swoop)

## disable physics processing on activation (waits for start signal)
func _on_entity_activated() -> void:
	super._on_entity_activated()
	set_physics_process(false)
