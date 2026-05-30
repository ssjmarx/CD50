# DirectMovementLeg
# Hard-sets velocity from a directional input signal
# Zeros velocity when no input is received (no momentum drift)

class_name DirectMovementLeg extends CDEntityComponent

# --- exports ---

# movement speed in pixels per second
@export var speed: float = 200.0

# directional input signals (Vector2 direction)
@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]

# --- state ---

# last received direction, normalized
var _direction: Vector2 = Vector2.ZERO
# whether input was received this frame
var _received_input: bool = false

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

# store direction and mark input received
func _on_move(direction: Vector2) -> void:
	_direction = direction.normalized()
	_received_input = true

# --- processing ---

# set velocity to direction * speed, or zero if no input this frame
func _physics_process(_delta: float) -> void:
	if _received_input:
		entity.request_velocity_set(_direction * speed)
		_received_input = false
	else:
		entity.request_velocity_set(Vector2.ZERO)

# --- cleanup ---

# reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_direction = Vector2.ZERO
	_received_input = false
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
