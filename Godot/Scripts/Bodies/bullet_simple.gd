# Simple arcade bullet. Draws a white square and sets up collision shapes from a radius export.

extends UniversalBody

# Appearance
@export var radius: float = 4.0 

# Create rectangular collision shapes matching the radius
func _ready() -> void:	
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$HitBox/CollisionShape2D.shape = shape

# Draw a white square centered on the body
func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)