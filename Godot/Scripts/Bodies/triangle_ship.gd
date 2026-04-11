extends "res://Scripts/Core/UniversalBody.gd"

signal TriangleShipCollision

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

func _physics_process(delta: float) -> void:
	var collision = move_parent_physics(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		TriangleShipCollision.emit()
		var collider = collision.get_collider()
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)
