# Rotates toward mouse or joystick input. Speed in degrees per second.

extends UniversalComponent

@export var turning_speed: int = 100
@export var independent_aim: bool = false

var target_rotation: float = 0.0
var target_position: Vector2
var using_mouse: bool = false
var mouse_target: Vector2
var joystick_target: Vector2


# Connect to appropriate input signals based on mode
func _ready() -> void:
	if independent_aim:
		parent.aim.connect(_on_aim)
		parent.aim_at.connect(_on_aim_at)
	else:
		parent.move_to.connect(_on_move_to)

# Rotate toward target based on input mode
func _physics_process(delta: float) -> void:
	if independent_aim:
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
