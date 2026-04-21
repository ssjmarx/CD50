# Death effect for the triangle ship. Spawns spinning line fragments that
# drift outward and fade after a randomized lifetime.

extends UniversalComponent2D

# Fragment appearance and physics
@export var fragment_length: float = 12.0
@export var line_count: int = 4
@export var spread_speed: float = 12.0
@export var spin_speed: float = 1.0
@export var lifetime: float = 1.0

# Per-fragment state arrays
var positions: Array[Vector2] = []
var rotations: Array[float] = []
var rotation_speeds: Array[float] = []
var velocities: Array[Vector2] = []
var lifetimes: Array[float] = []

# Time since effect started
var elapsed_time: float = 0.0

# Configure timer and initialize fragment positions, velocities, and lifetimes
func _ready() -> void:
	$Timer.wait_time = lifetime
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

	for i in line_count:
		positions.append(Vector2.ZERO)

		var line_rotation = randf_range(0.0, TAU)
		rotations.append(line_rotation)

		var line_rotation_speed = randf_range(0.0, spin_speed)
		rotation_speeds.append(line_rotation_speed)

		var angle = randf_range(0.0, TAU)
		var speed = randf_range(spread_speed * 0.3, spread_speed)
		velocities.append(Vector2.from_angle(angle) * speed)

		var line_lifetime = randf_range(0.5 * lifetime, lifetime)
		lifetimes.append(line_lifetime)
		
		positions[i] += velocities[i]

# Move and rotate fragments each physics frame
func _physics_process(delta: float) -> void:
	elapsed_time += delta

	for i in positions.size():
		positions[i] += velocities[i] * delta
		rotations[i] += rotation_speeds[i] * delta

	queue_redraw()

# Draw each living fragment as a rotated line segment
func _draw() -> void:
	for i in line_count:
		if elapsed_time >= lifetimes[i]:
			continue
		var half = fragment_length / 2.0
		var start = positions[i] + Vector2(-half, 0).rotated(rotations[i])
		var end = positions[i] + Vector2(half, 0).rotated(rotations[i])
		draw_line(start, end, Color.WHITE)

# Clean up when the effect timer expires
func _on_timeout() -> void:
	queue_free()
