## burst of single-pixel particles that fly outward
class_name DeathParticleEffect extends CDEffect

@export var particle_count: int = 50
@export var spread_speed: float = 200.0
@export var particle_color: Color = Color.WHITE

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []

func _ready() -> void:
	super._ready()

	for i in particle_count:
		_positions.append(Vector2.ZERO)
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(spread_speed * 0.3, spread_speed)
		_velocities.append(Vector2.from_angle(angle) * speed)

func _physics_process(delta: float) -> void:
	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
	queue_redraw()

func _draw() -> void:
	for pos in _positions:
		draw_rect(Rect2(pos.x - 0.5, pos.y - 0.5, 1, 1), particle_color)
