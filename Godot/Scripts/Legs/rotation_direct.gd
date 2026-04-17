# Tank-style rotation based on horizontal input direction. Speed in degrees per second.

extends UniversalComponent

@export var turning_speed: int = 100 # Degrees per second

var turning_left: bool = false # Left rotation state
var turning_right: bool = false # Right rotation state


# Connect to movement input signal
func _ready() -> void:
	parent.move.connect(_on_move)

# Apply rotation based on current state
func _physics_process(delta: float) -> void:
	if turning_right:
		parent.rotation += deg_to_rad(turning_speed) * delta
	if turning_left:
		parent.rotation -= deg_to_rad(turning_speed) * delta

# Set rotation state based on input direction
func _on_move(direction: Vector2) -> void:
	if direction.x > 0:
		turning_right = true
		turning_left = false
	elif direction.x < 0:
		turning_left = true
		turning_right = false
	else:
		turning_left = false
		turning_right = false
