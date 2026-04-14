extends "res://Scripts/Core/universal_body.gd"

var health_color = Color.WHITE

func _draw() -> void:
	var hp = $Health.current_health
	match hp:
		1: health_color = Color.GREEN
		2: health_color = Color.YELLOW
		3: health_color = Color.ORANGE
		4: health_color = Color.RED
		_: health_color = Color.WHITE
			
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), health_color)

func _on_health_health_changed(_current_health: Variant) -> void:
	queue_redraw()
