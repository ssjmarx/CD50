# Standard velocity bounce on physics collision. Applies velocity.bounce(normal) when the parent collides.

extends UniversalComponent

# Connect to parent's collision signal
func _ready() -> void:
	parent.body_collided.connect(_on_body_collided)

# Bounce velocity off the collision normal
func _on_body_collided(_collider: Node, normal: Vector2) -> void:
	parent.velocity = parent.velocity.bounce(normal)
