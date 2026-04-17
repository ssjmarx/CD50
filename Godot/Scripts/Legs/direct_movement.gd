# Direct movement leg. Converts move signals to velocity, or follows mouse position.

extends UniversalComponent

@export var speed: int = 600 # Pixels per second
@export var mouse_enabled: bool = true # Allow mouse following
@export var use_physics: bool = false # Use collision detection

var input: Vector2 # Movement direction from keyboard/joystick
var target: Vector2 # Mouse target position
var using_mouse: bool = false # Track input mode


# Move based on current input mode
func _physics_process(delta: float) -> void:
	if not using_mouse:
		if use_physics:
			parent.move_parent_physics(input * speed * delta)
		else:
			parent.move_parent(input * speed * delta)
	else:
		if use_physics:
			parent.move_parent_physics_toward(target, speed * delta)
		else:
			parent.move_parent_toward(target, speed * delta)

# Connect to movement signals
func _ready() -> void:
	parent.move.connect(_on_move)
	parent.move_to.connect(_on_move_to)

# Store direction input and switch to keyboard mode
func _on_move(direction: Vector2) -> void:
	input = direction
	if direction != Vector2.ZERO:
		using_mouse = false

# Store mouse position and switch to mouse mode
func _on_move_to(mouse_pos: Vector2) -> void:
	if mouse_enabled:
		target = mouse_pos
		using_mouse = true
