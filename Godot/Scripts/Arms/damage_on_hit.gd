extends UniversalComponent

@export var target_groups: Array[String] = []
@export var damage_amount: int = 1
@export var listen_signal: String = "body_collided"

func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

func _on_collision(collider: Node, _normal: Vector2) -> void:
	if target_groups.is_empty() and collider.has_node("Health"):
		collider.get_node("Health").reduce_health(damage_amount)
	
	for group in target_groups:
		if collider.is_in_group(group) and collider.has_node("Health"):
			collider.get_node("Health").reduce_health(damage_amount)
			return
