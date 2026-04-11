# asteroid.  moves with godot's in-built physics.  three selectable sizes.

extends "res://Scripts/Core/UniversalBody.gd"

signal AsteroidCollision

@export var initial_velocity: Vector2 = Vector2.ZERO
@export var initial_size: Size = Size.LARGE
@export var num_vertices: int = 10
@export var jaggedness: float = 0.3

var points: PackedVector2Array

enum Size {
	SMALL,
	MEDIUM,
	LARGE
	}

var radius: float:
	get:
		match initial_size:
			Size.LARGE: return 20.0
			Size.MEDIUM: return 10.0
			Size.SMALL: return 5.0
		return 20.0

func _ready() -> void:
	add_to_group("asteroids")
	
	points = _generate_jagged_points()
	
	$CollisionPolygon2D.polygon = points
	$HitBox/CollisionPolygon2D.polygon = points
	$HurtBox/CollisionPolygon2D.polygon = points
	
	if velocity == Vector2.ZERO:
		velocity = initial_velocity

func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	var collision = move_parent_physics(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		AsteroidCollision.emit()
		
		var collider = collision.get_collider()
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)

func _draw() -> void:
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color.WHITE, 2.0)

func _generate_jagged_points() -> PackedVector2Array:
	var jagged: PackedVector2Array = []
	for i in num_vertices:
		var angle := (TAU / num_vertices) * i
		var r := radius * (1.0 + randf_range(-jaggedness, jaggedness))
		jagged.append(Vector2(cos(angle), sin(angle)) * r)
	return jagged
