# Death effect that spawns particles that fly outward and fade after a set lifetime.
# Draws particles as single-pixel dots using custom _draw.

extends UniversalComponent2D

# Particle configuration
@export var particle_count: int = 50
@export var spread_speed: float = 200.0
@export var lifetime: float = 0.25

# Particle state
var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []

# Initialize particles with random directions and start the lifetime timer
func _ready() -> void:
	$Timer.wait_time = lifetime
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

	for i in particle_count:
		positions.append(Vector2.ZERO)
		var angle = randf_range(0.0, TAU)
		var speed = randf_range(spread_speed * 0.3, spread_speed)
		velocities.append(Vector2.from_angle(angle) * speed)

# Move particles outward each frame and redraw
func _physics_process(delta: float) -> void:
	for i in positions.size():
		positions[i] += velocities[i] * delta
	queue_redraw()

# Draw each particle as a single pixel
func _draw() -> void:
	for pos in positions:
		draw_rect(Rect2(pos.x - 0.5, pos.y - 0.5, 1, 1), Color.WHITE)

# Clean up when lifetime expires
func _on_timeout() -> void:
	queue_free()
