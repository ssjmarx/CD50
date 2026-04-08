# Asteroids-style screen-wrap behavior.  Warps attached parent to the other side of the screen when they go off it.

extends Node

@export var margin: int = 8

@onready var parent = get_parent()
@onready var viewport_size: Vector2 = get_viewport().get_visible_rect().size

func _physics_process(delta: float) -> void:
	pass
