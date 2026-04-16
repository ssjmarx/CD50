# Asteroids player ship with triangular shape and physics bouncing.

extends "res://Scripts/Core/universal_body.gd"

# Emitted when ship collides with physics body
signal triangle_ship_collision

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
	draw_polyline(points, Color.WHITE, 2.0)

# Initialize ship
func _ready() -> void:
	super._ready()

# Move and bounce on collision
func _physics_process(delta: float) -> void:
	var collision = move_parent_physics(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		triangle_ship_collision.emit()
		# Damage colliders with Health component
		var collider = collision.get_collider()
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)
