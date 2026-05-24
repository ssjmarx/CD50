# Complex engine with acceleration ramp-up/down (jerk). Smooth thrust response.

extends UniversalComponent

@export var max_acceleration: int = 400
@export var jerk: int = 400
@export var button_only: bool = true

var current_acceleration: float = 0.0
var thrusting: bool = false
var joystick_input: bool = false


# Connect to input signals
func _ready() -> void:
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)

# Ramp acceleration up/down based on input, apply to velocity
func _physics_process(delta: float):
	if thrusting or joystick_input:
		current_acceleration = min(current_acceleration + jerk * delta, max_acceleration)
	else:
		current_acceleration = maxf(current_acceleration - jerk * delta, 0.0)
	
	var forward = Vector2.from_angle(parent.rotation)
	if thrusting or joystick_input:
		parent.velocity += forward * current_acceleration * delta

# Track joystick input if not button-only mode
func _on_move(joystick: Vector2) -> void:
	if button_only:
		return
	if joystick == Vector2.ZERO:
		joystick_input = false
		parent.end_thrust.emit()
	else:
		joystick_input = true
		parent.thrust.emit()

# Start thrusting
func _on_thrust() -> void:
	thrusting = true

# Stop thrusting
func _on_end_thrust() -> void:
	thrusting = false
