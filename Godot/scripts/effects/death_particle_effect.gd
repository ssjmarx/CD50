# DeathParticleEffect
# Burst of single-pixel particles that fly outward
# Used for entity death explosions

class_name DeathParticleEffect extends CDEffect

# number of particles in the burst
@export var particle_count: int = 50

# maximum outward speed per particle
@export var spread_speed: float = 200.0

# color of the particles
@export var particle_color: Color = Color.WHITE

# per-particle state arrays
var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []

# initialize particle arrays with random outward velocities
func _ready() -> void:
	super._ready()

	for i in particle_count:
		_positions.append(Vector2.ZERO)

		# random direction with speed variance
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(spread_speed * 0.3, spread_speed)
		_velocities.append(Vector2.from_angle(angle) * speed)

# update particle positions and trigger redraw
func _physics_process(delta: float) -> void:
	for i in _positions.size():
		_positions[i] += _velocities[i] * delta
	queue_redraw()

# draw each particle as a single-pixel rectangle
func _draw() -> void:
	for pos in _positions:
		draw_rect(Rect2(pos.x - 0.5, pos.y - 0.5, 1, 1), particle_color)