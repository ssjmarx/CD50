extends UniversalComponent2D

@export var fragment_length: float = 12.0
@export var line_count: int = 4
@export var spread_speed: float = 12.0
@export var spin_speed: float = 1
@export var lifetime: float = 1

var positions: Array[Vector2] = []
var rotations: Array[float] = []
var rotation_speeds: Array[float] = []
var velocities: Array[Vector2] = []
var lifetimes: Array[float] = []

var elapsed_time = 0.0

func _ready() -> void:
	$Timer.wait_time = lifetime
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

	for i in line_count:
		positions.append(Vector2.ZERO)

		var line_rotation = randf_range(0.0, TAU)
		rotations.append(line_rotation)

		var line_rotation_speeds = randf_range(0.0, spin_speed)
		rotation_speeds.append(line_rotation_speeds)

		var angle = randf_range(0.0, TAU)
		var speed = randf_range(spread_speed * 0.3, spread_speed)
		velocities.append(Vector2.from_angle(angle) * speed)

		var line_lifetime = randf_range(0.5 * lifetime, lifetime)
		lifetimes.append(line_lifetime)
		
		positions[i] += velocities[i]

func _physics_process(delta: float) -> void:
	elapsed_time += delta

	for i in positions.size():
		positions[i] += velocities[i] * delta
		rotations[i] += rotation_speeds[i] * delta

	queue_redraw()

func _draw() -> void:
	for i in line_count:
		if elapsed_time >= lifetimes[i]:
			continue
		var half = fragment_length / 2.0
		var start = positions[i] + Vector2(-half, 0).rotated(rotations[i])
		var end = positions[i] + Vector2(half, 0).rotated(rotations[i])
		draw_line(start, end, Color.WHITE)

func _on_timeout() -> void:
	queue_free()
