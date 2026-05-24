# Asteroids player ship. Draws a triangular outline with a notched tail.

extends UniversalBody

# Appearance
@export var color: Color = Color.WHITE

# Ship polygon vertices (pointed nose, notched tail)
var points: Array = [
	Vector2(10, 0),
	Vector2(-5, -5),
	Vector2(-4, -2),
	Vector2(-4, 2),
	Vector2(-5, 5),
	Vector2(10, 0),
	]

# Draw the ship outline
func _draw() -> void:
	draw_polyline(points, color, 2.0, true)