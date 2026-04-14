# entity with a configurable hitbox, needs a sprite, is defined by its attached legs and brains

extends "res://Scripts/Core/universal_body.gd"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	super._ready()
	collision_shape.shape.size = Vector2(width, height)
