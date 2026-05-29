## lightweight visual effect — plays once and auto-frees
class_name CDEffect extends Node2D

@export var lifetime: float = 1.0

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
