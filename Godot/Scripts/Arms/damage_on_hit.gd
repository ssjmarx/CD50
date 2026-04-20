# Deals damage to colliding entities that have a Health component.
# Listens for collision signals and applies damage based on target group filters.

extends UniversalComponent

# Damage configuration
@export var target_groups: Array[String] = []
@export var damage_amount: int = 1
@export var listen_signal: String = "body_collided"

# Connect to the specified collision signal on the parent body
func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

# Apply damage to the collider if it matches target groups (or any entity if no groups specified)
func _on_collision(collider: Node, _normal: Vector2) -> void:
	if target_groups.is_empty() and collider.has_node("Health"):
		collider.get_node("Health").reduce_health(damage_amount)
	
	for group in target_groups:
		if collider.is_in_group(group) and collider.has_node("Health"):
			collider.get_node("Health").reduce_health(damage_amount)
			return