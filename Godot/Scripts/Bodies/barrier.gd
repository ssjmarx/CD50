extends UniversalComponent2D

func _ready() -> void:
	for child in get_children():
		if child.has_method("set") and "use_health_color" in child:
			child.use_health_color = false
