# Asteroid with procedural jagged polygon and physics bouncing. Three selectable sizes.

extends UniversalBody

@export var size: Size = Size.LARGE
@export var num_vertices: int = 10
@export var jaggedness: float = 0.3

var points: PackedVector2Array

enum Size {
	SMALL,
	MEDIUM,
	LARGE
	}

# Get radius based on size enum
var radius: float:
	get:
		match size:
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

# Set collision polygon on all colliders
func _setup_collision_polygons(poly_points: PackedVector2Array) -> void:
	$CollisionPolygon2D.polygon = poly_points
	$HitBox/CollisionPolygon2D.polygon = poly_points
	$HurtBox/CollisionPolygon2D.polygon = poly_points

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
