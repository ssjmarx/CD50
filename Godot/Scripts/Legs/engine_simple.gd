# Simple engine for Asteroids-style thrust. Accelerates forward, caps at top speed.

extends UniversalComponent

# Engine configuration
@export var acceleration: int = 170
@export var top_speed: int = 300
@export var button_only: bool = true

# Runtime state
var thrusting: bool = false
var joystick_input: bool = false


# Connect to input signals
func _ready() -> void:
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)

# Track joystick input if not button-only mode
func _on_move(joystick: Vector2) -> void:
	if button_only == true:
		return
	if joystick == Vector2.ZERO:
		joystick_input = false
	else:
		joystick_input = true

# Apply acceleration in forward direction, limit speed
func _physics_process(delta: float):
	var forward = Vector2.from_angle(parent.rotation)
	if thrusting or joystick_input:
		parent.velocity += forward * acceleration * delta
	if top_speed > 0:
		parent.velocity = parent.velocity.limit_length(top_speed)

# Start thrusting
func _on_thrust() -> void:
	thrusting = true

# Stop thrusting
func _on_end_thrust() -> void:
	thrusting = false
