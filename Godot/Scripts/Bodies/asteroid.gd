# Asteroid with procedural jagged polygon and physics bouncing. Three selectable sizes.

extends UniversalBody

@export var initial_velocity: Vector2 = Vector2.ZERO # Starting drift velocity
@export var initial_size: Size = Size.LARGE # Asteroid size enum
@export var num_vertices: int = 10 # Number of polygon vertices
@export var jaggedness: float = 0.3 # Random radius variation (0.0 = circle, 1.0 = chaotic)

var points: PackedVector2Array # Generated polygon vertices

enum Size {
	SMALL,   # Radius 5
	MEDIUM,  # Radius 10
	LARGE     # Radius 20
	}

# Get radius based on size enum
var radius: float:
	get:
		match initial_size:
			Size.LARGE: return 20.0
			Size.MEDIUM: return 10.0
			Size.SMALL: return 5.0
		return 20.0

# Initialize asteroid
func _ready() -> void:
	add_to_group("asteroids")
	
	points = _generate_jagged_points()
	
	# Defer polygon setup to avoid physics query flushing errors
	_setup_collision_polygons.call_deferred(points)
	
	if velocity == Vector2.ZERO:
		velocity = initial_velocity

# Set collision polygon on all colliders
func _setup_collision_polygons(poly_points: PackedVector2Array) -> void:
	$CollisionPolygon2D.polygon = poly_points
	$HitBox/CollisionPolygon2D.polygon = poly_points
	$HurtBox/CollisionPolygon2D.polygon = poly_points

# Move and bounce on collision
func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	var collision = move_parent_physics(velocity * delta)
	
	if collision:
		# Damage colliders with Health component
		var collider = collision.get_collider()
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)

# Draw white outline polygon
func _draw() -> void:
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color.WHITE, 2.0)

# Generate random jagged polygon vertices
func _generate_jagged_points() -> PackedVector2Array:
	var jagged: PackedVector2Array = []
	for i in num_vertices:
		var angle := (TAU / num_vertices) * i
		var r := radius * (1.0 + randf_range(-jaggedness, jaggedness))
		jagged.append(Vector2(cos(angle), sin(angle)) * r)
	return jagged
