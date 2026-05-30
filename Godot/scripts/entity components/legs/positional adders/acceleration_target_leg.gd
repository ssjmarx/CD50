# AccelerationTargetLeg
# Accelerates toward a world-space target with distance-based deceleration
# Tapers force within slow_distance, stops adding at stop_distance

class_name AccelerationTargetLeg extends CDEntityComponent

# --- exports ---

# acceleration magnitude in pixels per second squared
@export var acceleration: float = 800.0
# begins tapering acceleration within this distance
@export var slow_distance: float = 100.0
# acceleration reaches zero at this distance
@export var stop_distance: float = 5.0

# target position signals (Vector2 world position)
@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

# --- state ---

# current target position
var _target: Vector2 = Vector2.ZERO
# whether a valid target has been received
var _has_target: bool = false

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# connect target listeners
func _on_initialize() -> void:
	for sig in target_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_target)

# --- signal handlers ---

# store target position
func _on_target(target: Vector2) -> void:
	_target = target
	_has_target = true

# --- processing ---

# add scaled acceleration force toward target each frame
func _physics_process(delta: float) -> void:
	if not entity or not _has_target:
		return
	
	var to_target := _target - entity.global_position
	var distance := to_target.length()
	
	# stop accelerating when close enough
	if distance <= stop_distance:
		_has_target = false
		return
	
	# scale acceleration by distance (full at slow_distance, zero at stop_distance)
	var direction := to_target.normalized()
	var accel_factor := clampf(
		(distance - stop_distance) / (slow_distance - stop_distance),
		0.0, 1.0
	)
	
	entity.request_velocity_add(direction * acceleration * accel_factor * delta)

# --- cleanup ---

# reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_target = Vector2.ZERO
	_has_target = false
	for sig in target_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
