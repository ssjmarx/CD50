# Spawns bodies in a ring pattern around the parent. Supports optional orbiting movement.

extends UniversalComponent

# Spawn configuration
@export var spawn_scene: PackedScene
@export var ring_radius: float = 30.0
@export var spawn_count: int = 12
@export var component_size: Vector2 = Vector2(4, 4)
@export var component_health: int = 1
@export var spawn_groups: Array[String] = ["bricks"]
@export var orbit_speed: float = 0.0

var _bricks: Array[Dictionary] = []

# Instantiate all bodies in a ring, configure size/health/groups, and add to game
func _ready() -> void:
	for i: int in spawn_count:
		var angle: float = TAU * i / spawn_count
		
		var body: CharacterBody2D = spawn_scene.instantiate()
		body.width = component_size.x
		body.height = component_size.y
		
		# Update the first collision shape to match brick size
		for child: Node in body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				if child.shape is RectangleShape2D:
					child.shape.size = component_size
				break
		
		body.position = Vector2.from_angle(angle) * ring_radius
		
		# Configure health if the Health component is present
		if body.has_node("Health"):
			var health: Node = body.get_node("Health")
			health.max_health = component_health
			health.current_health = component_health
		
		for group: String in spawn_groups:
			body.add_to_group(group)
		
		game.add_child.call_deferred(body)
		_bricks.append({node = body, angle = angle})

# Orbit all surviving bricks around the parent's position
func _process(delta: float) -> void:
	var center: Vector2 = parent.global_position
	
	for entry: Dictionary in _bricks:
		if !is_instance_valid(entry.node):
			continue
		
		if orbit_speed != 0.0:
			entry.angle += orbit_speed * delta
		
		entry.node.global_position = center + Vector2.from_angle(entry.angle) * ring_radius