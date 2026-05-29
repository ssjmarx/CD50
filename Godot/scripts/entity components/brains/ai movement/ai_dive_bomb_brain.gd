# AIDiveBombBrain
# Generates a sine-wave dive path toward a target on signal
# Follows waypoints via move_to, emits path_finished when complete

class_name AIDiveBombBrain extends CDEntityComponent

# groups to search for dive targets
@export var target_groups: Array[StringName] = [&"player"]

# sine wave length along the dive direction
@export var wavelength: float = 200.0

# sine wave amplitude perpendicular to dive direction
@export var amplitude: float = 80.0

# how far past the target the path extends
@export var overshoot: float = 200.0

# spacing between generated waypoints
@export var waypoint_spacing: float = 10.0

# distance to consider a waypoint reached
@export var arrival_distance: float = 5.0

@export_group("Listen Signals")
@export var dive_signals: Array[StringName] = [&"begin_dive"]

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]
@export var complete_signals: Array[StringName] = [&"path_finished"]

# generated sine-wave waypoints
var _waypoints: Array[Vector2] = []

# current waypoint index
var _current_index: int = 0

# whether currently executing a dive
var _is_diving: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure signals exist and connect dive trigger
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	for sig in complete_signals:
		entity.ensure_signal(sig)
	for sig in dive_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_begin_dive)

# generate the dive path and start following it
func _on_begin_dive(target_position: Vector2 = Vector2.ZERO) -> void:
	if _is_diving:
		return

	# use provided position or find nearest target
	var target_pos := target_position
	if target_pos == Vector2.ZERO:
		target_pos = _find_target_position()
	if target_pos == Vector2.ZERO:
		return

	_generate_dive_path(target_pos)
	_current_index = 0
	_is_diving = true
	set_physics_process(true)

# find the nearest target position from target groups
func _find_target_position() -> Vector2:
	for group in target_groups:
		var target := game.group_registry.get_nearest(group, entity.global_position)
		if target:
			return target.global_position
	return Vector2.ZERO

# build a sine-wave path from entity to target + overshoot
func _generate_dive_path(target_pos: Vector2) -> void:
	var start := entity.global_position
	_waypoints.clear()

	var to_target := target_pos - start
	var direction := to_target.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)

	var total_distance := to_target.length() + overshoot

	var dist := 0.0
	while dist <= total_distance:
		var sine_offset := sin(dist / wavelength * TAU) * amplitude
		var point := start + direction * dist + perpendicular * sine_offset
		_waypoints.append(point)
		dist += waypoint_spacing

# follow waypoints by emitting move_to positions
func _physics_process(_delta: float) -> void:
	if not _is_diving or _waypoints.is_empty():
		return

	var target := _waypoints[_current_index]
	for sig in move_signals:
		entity.emit_signal(sig, target)

	# advance to next waypoint when close enough
	if entity.global_position.distance_to(target) < arrival_distance:
		_current_index += 1
		if _current_index >= _waypoints.size():
			_is_diving = false
			for sig in complete_signals:
				entity.emit_signal(sig)
			set_physics_process(false)

# clean up dive state and disconnect signals
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_diving = false
	_waypoints.clear()
	_current_index = 0
	for sig in dive_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_begin_dive):
			entity.disconnect(sig, _on_begin_dive)

# disable physics processing on activation (waits for dive signal)
func _on_entity_activated() -> void:
	super._on_entity_activated()
	set_physics_process(false)