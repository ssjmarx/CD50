# Pong paddle. Draws a white rectangle sized from width/height exports.

extends UniversalBody

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Apply exported dimensions to the collision shape
func _ready() -> void:
	super._ready()
	collision_shape.shape.size = Vector2(width, height)

# Draw a white rectangle centered on the body
func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), Color.WHITE)
