# Asteroid with procedural jagged polygon. Three selectable sizes with radius-based generation.

extends UniversalBody

# Generation and appearance
@export var size: Size = Size.LARGE
@export var num_vertices: int = 10
@export var jaggedness: float = 0.3
@export var color: Color = Color.WHITE

enum Size {
	SMALL,
	MEDIUM,
	LARGE
	}

var points: PackedVector2Array

# Radius derived from size enum
var radius: float:
	get:
		match size:
			Size.LARGE: return 20.0
			Size.MEDIUM: return 10.0
			Size.SMALL: return 5.0
		return 20.0

# Generate polygon, join asteroids group, and defer collision setup
func _ready() -> void:
	add_to_group("asteroids")
	points = _generate_jagged_points()
	_setup_collision_polygons.call_deferred(points)

# Apply the polygon to all collision layers (CollisionPolygon2D, HitBox, HurtBox)
func _setup_collision_polygons(poly_points: PackedVector2Array) -> void:
	$CollisionPolygon2D.polygon = poly_points
	$HitBox/CollisionPolygon2D.polygon = poly_points
	$HurtBox/CollisionPolygon2D.polygon = poly_points

# Draw the polygon outline with the first point appended to close the loop
func _draw() -> void:
	var outline: PackedVector2Array = PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, color, 2.0)

# Build a jagged polygon by varying vertex distances from center
func _generate_jagged_points() -> PackedVector2Array:
	var jagged: PackedVector2Array = []
	for i in num_vertices:
		var angle: float = (TAU / num_vertices) * i
		var r: float = radius * (1.0 + randf_range(-jaggedness, jaggedness))
		jagged.append(Vector2(cos(angle), sin(angle)) * r)
	return jagged