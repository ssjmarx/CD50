# Pong-style paddle.  recieves controller inputs and outputs movement requests to legs

extends "res://Scripts/Core/UniversalBody.gd"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var deflector = $AngledDeflector

func _ready() -> void:
	super._ready()
	collision_shape.shape.size = Vector2(width, height)

func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), Color.WHITE)

func bounce_offset(ball_position: Vector2) -> Vector2:
	return deflector.bounce_offset(ball_position)
