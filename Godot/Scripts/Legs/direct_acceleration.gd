# Adds acceleration to velocity based on input. Like DirectMovement but accelerates instead of sets velocity.

extends UniversalComponent

# Movement configuration
@export var mouse_enabled: bool = false
@export var acceleration: int = 50

# Runtime state
var input: Vector2
var target: Vector2
var using_mouse: bool = false

# Add acceleration in direction of input or toward mouse
func _physics_process(delta):

	if not using_mouse:
		parent.velocity += input * acceleration * delta
	else:
		var direction: Vector2 = (target - parent.position).normalized()
		parent.velocity += direction * acceleration * delta

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
