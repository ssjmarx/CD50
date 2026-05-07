# Death effect for settled brick cells. Spawns spinning line fragments and
# particle dots that drift outward and fade, tinted to the parent's color.

extends UniversalComponent2D

# Fragment appearance and physics
@export var fragment_length: float = 10.0
@export var line_count: int = 4
@export var spread_speed: float = 60.0
@export var spin_speed: float = 3.0
@export var lifetime: float = 0.6

# Particle configuration
@export var particle_count: int = 8
@export var particle_size: float = 3.0
@export var particle_spread: float = 80.0

# Per-fragment state
var _frag_positions: Array[Vector2] = []
var _frag_rotations: Array[float] = []
var _frag_rotation_speeds: Array[float] = []
var _frag_velocities: Array[Vector2] = []
var _frag_lifetimes: Array[float] = []

# Per-particle state
var _part_positions: Array[Vector2] = []
var _part_velocities: Array[Vector2] = []
var _part_lifetimes: Array[float] = []

var _elapsed: float = 0.0
var _color: Color = Color.WHITE

func _ready() -> void:
	$Timer.wait_time = lifetime
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

	# Inherit color from parent if available
	if parent and "color" in parent:
		_color = parent.color

	# Initialize line fragments
	for i in line_count:
		_frag_positions.append(Vector2.ZERO)
		_frag_rotations.append(randf_range(0.0, TAU))
		_frag_rotation_speeds.append(randf_range(-spin_speed, spin_speed))

		var angle = randf_range(0.0, TAU)
		var speed = randf_range(spread_speed * 0.4, spread_speed)
		_frag_velocities.append(Vector2.from_angle(angle) * speed)
		_frag_lifetimes.append(randf_range(0.4 * lifetime, lifetime))

	# Initialize particles
	for i in particle_count:
		_part_positions.append(Vector2.ZERO)
		var angle = randf_range(0.0, TAU)
		var speed = randf_range(particle_spread * 0.3, particle_spread)
		_part_velocities.append(Vector2.from_angle(angle) * speed)
		_part_lifetimes.append(randf_range(0.3 * lifetime, lifetime))

func _physics_process(delta: float) -> void:
	_elapsed += delta

	for i in _frag_positions.size():
		_frag_positions[i] += _frag_velocities[i] * delta
		_frag_rotations[i] += _frag_rotation_speeds[i] * delta

	for i in _part_positions.size():
		_part_positions[i] += _part_velocities[i] * delta

	queue_redraw()

func _draw() -> void:
	# Draw line fragments
	for i in line_count:
		if _elapsed >= _frag_lifetimes[i]:
			continue
		var alpha = 1.0 - (_elapsed / _frag_lifetimes[i])
		var col = Color(_color.r, _color.g, _color.b, alpha)
		var half = fragment_length / 2.0
		var start = _frag_positions[i] + Vector2(-half, 0).rotated(_frag_rotations[i])
		var end = _frag_positions[i] + Vector2(half, 0).rotated(_frag_rotations[i])
		draw_line(start, end, col, 2.0)

	# Draw particles
	for i in particle_count:
		if _elapsed >= _part_lifetimes[i]:
			continue
		var alpha = 1.0 - (_elapsed / _part_lifetimes[i])
		var col = Color(_color.r, _color.g, _color.b, alpha)
		var half = particle_size / 2.0
		var rect = Rect2(_part_positions[i] - Vector2(half, half), Vector2(particle_size, particle_size))
		draw_rect(rect, col)

func _on_timeout() -> void:
	queue_free()