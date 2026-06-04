## CDEffect
## Lightweight visual effect — plays once and auto-frees
## Attach particles/sprites as children, set lifetime, done

class_name CDEffect extends Node2D

## seconds before this effect auto-destructs
@export var lifetime: float = 1.0

## create a one-shot timer that frees this node when it expires
func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
