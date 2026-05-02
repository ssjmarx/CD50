# Breakout brick with health-based coloring. Color shifts from green to red as HP decreases.

extends UniversalBody

@export var use_health_color: bool = true

var health_color: Color = Color.WHITE

# Color the brick based on current HP and set the score reward
func _draw() -> void:
	var hp: int = $Health.current_health
	if use_health_color:
		match hp:
			1: health_color = Color.GREEN
			2: health_color = Color.YELLOW
			3: health_color = Color.ORANGE
			4: health_color = Color.RED
			_: health_color = Color.WHITE
	else:
		health_color = Color.WHITE
		
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), health_color)

# Trigger a redraw whenever the Health component changes
func _on_health_health_changed(_current_health: Variant) -> void:
	queue_redraw()
