# Asteroids player ship with triangular shape and physics bouncing.

extends UniversalBody

@export var color: Color = Color.WHITE

# Ship polygon vertices (pointed nose, notched tail)
var points = [
	Vector2(10, 0),
	Vector2(-5, -5),
	Vector2(-4, -2),
	Vector2(-4, 2),
	Vector2(-5, 5),
	Vector2(10, 0),
	]

# Draw white triangle ship
func _draw() -> void:
	draw_polyline(points, color, 2.0)
