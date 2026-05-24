# Static friction that applies constant deceleration until velocity reaches zero.

extends UniversalComponent

# Friction configuration
@export var friction: int = 300

# Set high process priority to run after other movement components
func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50

# Apply constant friction to slow down
func _physics_process(delta: float):
	parent.velocity = parent.velocity.move_toward(Vector2.ZERO, friction * delta)
