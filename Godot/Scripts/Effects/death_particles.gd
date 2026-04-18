extends UniversalComponent2D

@export var particle_count: int = 50
@export var spread_speed: float = 200.0
@export var lifetime: float = 0.25

var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []

func _ready() -> void:
	$Timer.wait_time = lifetime
	$Timer.timeout.connect(_on_timeout)
	$Timer.start()

	for i in particle_count:
		positions.append(Vector2.ZERO)
		var angle = randf_range(0.0, TAU)
		var speed = randf_range(spread_speed * 0.3, spread_speed)
		velocities.append(Vector2.from_angle(angle) * speed)

func _physics_process(delta: float) -> void:
	for i in positions.size():
		positions[i] += velocities[i] * delta
	queue_redraw()

func _draw() -> void:
	for pos in positions:
		draw_rect(Rect2(pos.x - 0.5, pos.y - 0.5, 1, 1), Color.WHITE)

func _on_timeout() -> void:
	queue_free()
