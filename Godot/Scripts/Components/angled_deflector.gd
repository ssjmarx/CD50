# Pong-style deflection. Redirects velocity based on hit position relative to the collider, with configurable axis bias.

extends UniversalComponent

# Deflection configuration
@export var deflection_bias: Vector2 = Vector2(1, 1)
@export var target_group: String = "paddles"

# Connect to parent's collision signal
func _ready() -> void:
	parent.body_collided.connect(bounce_offset)

# Recalculate velocity direction from offset between parent and collider positions
func bounce_offset(collider: Node, _normal: Vector2) -> void:
	if not collider.is_in_group(target_group):
		return
	
	var raw_offset: Vector2 = (parent.global_position - collider.global_position).normalized()
	raw_offset.x *= deflection_bias.x
	raw_offset.y *= deflection_bias.y
	raw_offset = raw_offset.normalized()

	var speed: float = parent.velocity.length()
	parent.velocity = raw_offset * speed