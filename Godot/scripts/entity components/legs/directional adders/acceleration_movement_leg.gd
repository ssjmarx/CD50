# AccelerationMovementLeg
# Adds directional force each frame, building momentum over time
# Pair with a friction leg for speed control and deceleration

class_name AccelerationLeg extends CDEntityComponent

# --- exports ---

# acceleration magnitude in pixels per second squared
@export var acceleration: float = 800.0

# directional input signals (Vector2 direction)
@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]

# --- state ---

# last received direction, normalized
var _direction: Vector2 = Vector2.ZERO

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# connect move listeners
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)

# --- signal handlers ---

# store normalized direction
func _on_move(direction: Vector2) -> void:
	_direction = direction.normalized()

# --- processing ---

# add acceleration force in the stored direction each frame
func _physics_process(delta: float) -> void:
	if _direction != Vector2.ZERO:
		entity.request_velocity_add(_direction * acceleration * delta)

# --- cleanup ---

# reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_direction = Vector2.ZERO
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
