extends UniversalComponent

@export var spawn_scene: PackedScene
@export var ring_radius: float = 30.0
@export var spawn_count: int = 12
@export var brick_size: Vector2 = Vector2(4, 4)
@export var brick_health: int = 1
@export var spawn_groups: Array[String] = ["bricks"]
@export var orbit_speed: float = 0.0

var _bricks: Array[Dictionary] = []

func _ready() -> void:
	for i in spawn_count:
		var angle = TAU * i / spawn_count
		
		var body = spawn_scene.instantiate()
		body.width = brick_size.x
		body.height = brick_size.y
		
		for child in body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				if child.shape is RectangleShape2D:
					child.shape.size = brick_size
				break
		
		body.position = Vector2.from_angle(angle) * ring_radius
		
		if body.has_node("Health"):
			var health = body.get_node("Health")
			health.max_health = brick_health
			health.current_health = brick_health
		
		for group in spawn_groups:
			body.add_to_group(group)
		
		game.add_child.call_deferred(body)
		_bricks.append({node = body, angle = angle})

func _process(delta: float) -> void:
	var center = parent.global_position
	
	for entry in _bricks:
		if !is_instance_valid(entry.node):
			continue
		
		if orbit_speed != 0.0:
			entry.angle += orbit_speed * delta
		
		entry.node.global_position = center + Vector2.from_angle(entry.angle) * ring_radius
