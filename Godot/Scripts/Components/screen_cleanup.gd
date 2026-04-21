# Screen cleanup. Destroys the parent body after an activation delay
# if it moves outside the visible screen area with a margin.

extends UniversalComponent

# Cleanup configuration
@export var margin: int = 16
@export var activation_time: float = 3.0

# Screen bounds
@onready var bounds: Vector2 = get_viewport().get_visible_rect().size

# Time since spawn
var _counter: float = 0.0

# Wait for activation delay, then free parent if off-screen
func _physics_process(delta: float) -> void:
	_counter += delta
	if _counter < activation_time:
		return
	
	var pos: Vector2 = parent.global_position
	if pos.x < -margin or pos.x > bounds.x + margin or pos.y < -margin or pos.y > bounds.y + margin:
		parent.queue_free()
