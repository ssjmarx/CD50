extends Node

signal health_changed(current_health)

@export var max_health = 1

@onready var current_health = max_health

func reduce_health(amount):
	current_health -= amount
	emit_signal("health_changed", current_health)
	if current_health <= 0:
		die()

func die():
	get_parent().queue_free()
