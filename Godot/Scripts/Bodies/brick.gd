# Brick Breaker brick. Draws a white rectangle at configured width × height.
# Color is applied externally via modulate (by flag_palette or other components).

extends UniversalBody

func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), Color.WHITE)