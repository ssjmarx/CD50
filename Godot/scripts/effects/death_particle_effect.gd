## DeathParticleEffect
## Burst of single-pixel particles that fly outward
## Used for entity death explosions

class_name DeathParticleEffect extends CDEffect

## number of particles in the burst
@export var particle_count: int = 50

## maximum outward speed per particle
@export var spread_speed: float = 200.0

## per-particle state arrays
var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _particle_colors: Array[Color] = []

## initialize particle arrays with random outward velocities and colors
func _ready() -> void:
	super._ready()

	for i in particle_count:
		_positions.append(Vector2.ZERO)

		var angle := randf_range(0.0, TAU)
		var speed := randf_range(spread_speed * 0.3, spread_speed)
		_velocities.append(Vector2.from_angle(angle) * speed)
		
		_particle_colors.append(get_random_color())

## update particle positions and trigger redraw
func _physics_process(delta: float) -> void:
	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
	queue_redraw()

## draw each particle as a single-pixel rectangle
func _draw() -> void:
	for i in _positions.size():
		var pos = _positions[i]
		draw_rect(Rect2(pos.x - 0.5, pos.y - 0.5, 1, 1), _particle_colors[i])
