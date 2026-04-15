# Calculates Pong-style deflection based on hit position relative to parent.

extends Node

@export var deflection_bias: Vector2 = Vector2(1, 1) # Multiplier for x/y deflection strength

# Calculate bounce direction based on where ball hit the paddle
func bounce_offset(ball_position: Vector2) -> Vector2:
	var parent_node = get_parent()
	if not parent_node:
		return Vector2.ZERO
	
	var raw_offset = (ball_position - parent_node.global_position).normalized()
	raw_offset.x *= deflection_bias.x # Apply x-axis bias
	raw_offset.y *= deflection_bias.y # Apply y-axis bias
	#print("angled deflector returning bounce offset")
	return raw_offset.normalized()
