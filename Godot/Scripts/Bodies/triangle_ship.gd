extends "res://Scripts/Core/UniversalBody.gd"

var points = [
	Vector2(10, 0),
	Vector2(-5, -5),
	Vector2(-4, -2),
	Vector2(-4, 2),
	Vector2(-5, 5),
	Vector2(10, 0),
]


func _draw() -> void:
	draw_polyline(points, Color.WHITE, 2.0)

func _ready() -> void:
	super._ready()
