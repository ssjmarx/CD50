# Screen cleanup. Destroys the parent body after an activation delay
# if it moves outside the playfield area with a margin.

extends UniversalComponent

# Cleanup configuration
@export var margin: int = 16
@export var activation_time: float = 3.0

# Playfield bounds (from game.playfield_size, fallback to viewport)
var bounds: Vector2

# Time since spawn
var _counter: float = 0.0

# Initialize bounds from game playfield_size, fallback to viewport
func _ready() -> void:
	if game and "playfield_size" in game:
		bounds = game.playfield_size
	else:
		bounds = get_viewport().get_visible_rect().size

# Wait for activation delay, then free parent if off-screen
func _physics_process(delta: float) -> void:
	_counter += delta
	if _counter < activation_time:
		return
	
	var pos: Vector2 = parent.global_position
	if pos.x < -margin or pos.x > bounds.x + margin or pos.y < -margin or pos.y > bounds.y + margin:
		parent.queue_free()
