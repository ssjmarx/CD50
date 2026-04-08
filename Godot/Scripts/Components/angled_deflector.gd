# Calculates Pong-style deflection on a colliding object.

extends Node

@export var deflection_bias: Vector2 = Vector2(1, 1)

@onready var parent = get_parent()

func bounce_offset(ball_position: Vector2) -> Vector2:
	var raw_offset = (ball_position - parent.global_position).normalized()
	raw_offset.x *= deflection_bias.x
	raw_offset.y *= deflection_bias.y
	return raw_offset.normalized()
