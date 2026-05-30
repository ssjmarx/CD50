# BrokenShipEffect
# Spinning line fragments that drift outward and fade
# Used for ship death effects

class_name BrokenShipEffect extends CDEffect

# length of each line fragment
@export var fragment_length: float = 12.0

# number of fragments to spawn
@export var line_count: int = 4

# maximum outward drift speed per fragment
@export var spread_speed: float = 12.0

# maximum rotation speed per fragment
@export var spin_speed: float = 1.0

# color of the line fragments
@export var fragment_color: Color = Color.WHITE

# per-fragment state arrays
var _positions: Array[Vector2] = []
var _rotations: Array[float] = []
var _rotation_speeds: Array[float] = []
var _velocities: Array[Vector2] = []
var _lifetimes: Array[float] = []

# total elapsed time for lifetime checks
var _elapsed: float = 0.0

# initialize fragment arrays with random directions and speeds
func _ready() -> void:
	super._ready()

	for i in line_count:
		_positions.append(Vector2.ZERO)
		_rotations.append(randf_range(0.0, TAU))
		_rotation_speeds.append(randf_range(0.0, spin_speed))

		# random outward velocity
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(spread_speed * 0.3, spread_speed)
		_velocities.append(Vector2.from_angle(angle) * speed)

		# random lifetime per fragment (staggered fade-out)
		_lifetimes.append(randf_range(0.5 * lifetime, lifetime))

		# initial position offset
		_positions[i] += _velocities[i]

# update fragment positions, rotations, and trigger redraw
func _physics_process(delta: float) -> void:
	_elapsed += delta

	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
		_rotations[i] += _rotation_speeds[i] * delta

	queue_redraw()

# draw each fragment as a rotated line segment, skip expired fragments
func _draw() -> void:
	for i in line_count:
		if _elapsed >= _lifetimes[i]:
			continue
		var half := fragment_length / 2.0
		var start := _positions[i] + Vector2(-half, 0).rotated(_rotations[i])
		var end := _positions[i] + Vector2(half, 0).rotated(_rotations[i])
		draw_line(start, end, fragment_color)
