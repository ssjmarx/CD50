# Space Rocks player ship. Draws a triangular outline with a notched tail.

extends UniversalBody

# Appearance
@export var color: Color = Color.WHITE

# Ship polygon vertices (blunt nose, extended wings)
var points: Array = [
	Vector2(8, 0),
	Vector2(-6, -5),
	Vector2(-4.5, -2.5),
	Vector2(-4.5, 2.5),
	Vector2(-6, 5),
	Vector2(8, 0),
	]

# Draw the ship outline
func _draw() -> void:
	draw_polyline(points, color, 1.0, true)
