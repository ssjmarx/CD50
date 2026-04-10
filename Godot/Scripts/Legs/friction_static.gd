extends Node2D

@export var friction: int = 600

@onready var parent = get_parent()

func _ready() -> void:
	process_priority = 50
	process_physics_priority = 50

func _physics_process(delta):
	parent.velocity = parent.velocity.move_toward(Vector2.ZERO, friction * delta)
