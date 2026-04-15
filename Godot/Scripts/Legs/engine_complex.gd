# Complex engine with acceleration ramp-up/down (jerk). Smooth thrust response.

extends Node

@export var max_acceleration: int = 400 # Max pixels per second squared
@export var jerk: int = 400 # Rate of acceleration change
@export var button_only: bool = true # Only thrust on button press

var current_acceleration: float = 0.0 # Current acceleration level
var thrusting: bool = false # Thrust button state
var joystick_input: bool = false # Joystick input state

@onready var parent = get_parent() # Reference to attached body

# Connect to input signals
func _ready() -> void:
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)

# Ramp acceleration up/down based on input, apply to velocity
func _physics_process(delta):
	if thrusting or joystick_input:
		current_acceleration = min(current_acceleration + jerk * delta, max_acceleration)
	else:
		current_acceleration = maxf(current_acceleration - jerk * delta, 0.0)
	
	var forward = Vector2.from_angle(parent.rotation)
	if thrusting or joystick_input:
		parent.velocity += forward * current_acceleration * delta

# Track joystick input if not button-only mode
func _on_move(joystick: Vector2) -> void:
	if button_only == true:
		return
	if joystick == Vector2.ZERO:
		joystick_input = false
	else:
		joystick_input = true

# Start thrusting
func _on_thrust() -> void:
	thrusting = true

# Stop thrusting
func _on_end_thrust() -> void:
	thrusting = false
