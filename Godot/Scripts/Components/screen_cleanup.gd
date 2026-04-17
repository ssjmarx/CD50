extends UniversalComponent

@export var margin: int = 16

@onready var bounds: Vector2 = get_viewport().get_visible_rect().size

func _physics_process(_delta: float) -> void:
	var pos = parent.global_position
	if pos.x < -margin or pos.x > bounds.x + margin or pos.y < -margin or pos.y > bounds.y + margin:
		parent.queue_free()
