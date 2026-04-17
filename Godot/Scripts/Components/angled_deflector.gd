# Calculates Pong-style deflection based on hit position relative to parent.

extends UniversalComponent

@export var deflection_bias: Vector2 = Vector2(1, 1)
@export var target_group: String = "paddles"


# Connect it uuuuup
func _ready() -> void:
	parent.body_collided.connect(bounce_offset)

# Calculate bounce direction based on where ball hit the paddle
func bounce_offset(collider: Node, _normal: Vector2) -> void:
	if not collider.is_in_group(target_group):
		return
	
	var raw_offset = (parent.global_position - collider.global_position).normalized()
	raw_offset.x *= deflection_bias.x
	raw_offset.y *= deflection_bias.y
	raw_offset = raw_offset.normalized()

	var speed = parent.velocity.length()
	parent.velocity = raw_offset * speed
