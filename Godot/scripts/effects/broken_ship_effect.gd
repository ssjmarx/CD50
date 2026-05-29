## spinning line fragments that drift outward and fade
class_name BrokenTriangleEffect extends CDEffect

@export var fragment_length: float = 12.0
@export var line_count: int = 4
@export var spread_speed: float = 12.0
@export var spin_speed: float = 1.0
@export var fragment_color: Color = Color.WHITE

var _positions: Array[Vector2] = []
var _rotations: Array[float] = []
var _rotation_speeds: Array[float] = []
var _velocities: Array[Vector2] = []
var _lifetimes: Array[float] = []
var _elapsed: float = 0.0

func _ready() -> void:
	super._ready()

	for i in line_count:
		_positions.append(Vector2.ZERO)

		var line_rotation := randf_range(0.0, TAU)
		_rotations.append(line_rotation)

		_rotation_speeds.append(randf_range(0.0, spin_speed))

		var angle := randf_range(0.0, TAU)
		var speed := randf_range(spread_speed * 0.3, spread_speed)
		_velocities.append(Vector2.from_angle(angle) * speed)

		_lifetimes.append(randf_range(0.5 * lifetime, lifetime))

		_positions[i] += _velocities[i]

func _physics_process(delta: float) -> void:
	_elapsed += delta

	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
		_rotations[i] += _rotation_speeds[i] * delta

	queue_redraw()

func _draw() -> void:
	for i in line_count:
		if _elapsed >= _lifetimes[i]:
			continue
		var half := fragment_length / 2.0
		var start := _positions[i] + Vector2(-half, 0).rotated(_rotations[i])
		var end := _positions[i] + Vector2(half, 0).rotated(_rotations[i])
		draw_line(start, end, fragment_color)
