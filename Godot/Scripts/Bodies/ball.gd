# Pong ball. Draws a colored square and sets up collision shapes from a radius export.

extends UniversalBody

# Appearance
@export var radius: float = 4.0 
@export var color: Color = Color.WHITE

# Create rectangular collision shapes matching the radius
func _ready() -> void:
	super._ready()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$HitBox/CollisionShape2D.shape = shape

# Draw ball
func _draw() -> void:
	var half: float = radius / 2.0
	draw_rect(Rect2(-half, -half, radius, radius), color)