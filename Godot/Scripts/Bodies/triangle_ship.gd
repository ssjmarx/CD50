# Asteroids player ship with triangular shape and physics bouncing.

extends UniversalBody

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
		# Damage colliders with Health component
		var collider = collision.get_collider()
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)
