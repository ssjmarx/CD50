# Asteroids-style screen-wrap behavior.  Warps attached parent to the other side of the screen when they go off it.

extends Node

@export var margin: int = 8

@onready var parent = get_parent()
@onready var viewport_size: Vector2 = get_viewport().get_visible_rect().size

func _physics_process(_delta: float) -> void:
	if parent.global_position.x > viewport_size.x + margin:
		parent.global_position.x = 0.0 - margin
		parent.reset_physics_interpolation()

	if parent.global_position.x < 0.0 - margin:
		parent.global_position.x = viewport_size.x
		parent.reset_physics_interpolation()

	if parent.global_position.y > viewport_size.y + margin:
		parent.global_position.y = 0.0
		parent.reset_physics_interpolation()

	if parent.global_position.y < 0.0 - margin:
		parent.global_position.y = viewport_size.y
		parent.reset_physics_interpolation()
