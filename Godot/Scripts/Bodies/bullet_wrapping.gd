# simple arcade bullet.  plays a sound when it hits.

extends UniversalBody

@export var initial_velocity: Vector2 = Vector2(0, 0)
@export var radius: float = 4.0 

# Set up collision shapes
func _ready() -> void:	
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$HitBox/CollisionShape2D.shape = shape

# Draw white square
func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)
