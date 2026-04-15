# Rotates toward mouse or joystick input. Speed in degrees per second.

extends Node

@export var turning_speed: int = 100 # Degrees per second
@export var independant_aim: bool = false # Use aim signals instead of move signals

var target_rotation: float = 0.0 # Target angle to rotate toward
var target_position: Vector2 # Target position for mouse aim
var using_mouse: bool = false # Track input mode
var mouse_target: Vector2 # Stored mouse position
var joystick_target: Vector2 # Stored joystick direction

@onready var parent = get_parent() # Reference to attached body

# Connect to appropriate input signals based on mode
func _ready() -> void:
	if independant_aim:
		parent.aim.connect(_on_aim)
		parent.aim_at.connect(_on_aim_at)
	else:
		parent.move_to.connect(_on_move_to)

# Rotate toward target based on input mode
func _physics_process(delta: float) -> void:
	if independant_aim:
		if using_mouse:
			target_position = mouse_target
			target_rotation = (target_position - parent.position).angle()
		else:
			target_rotation = joystick_target.angle()
	
	parent.rotation = rotate_toward(parent.rotation, target_rotation, deg_to_rad(turning_speed) * delta)

# Store mouse position for rotation target
func _on_move_to(mouse_pos: Vector2) -> void:
	target_position = mouse_pos

# Store mouse position and switch to mouse mode
func _on_aim_at(mouse_pos: Vector2) -> void:
	if mouse_pos != Vector2.ZERO:
		using_mouse = true
		mouse_target = mouse_pos

# Store joystick direction and switch to joystick mode
func _on_aim(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		using_mouse = false
		joystick_target = direction
