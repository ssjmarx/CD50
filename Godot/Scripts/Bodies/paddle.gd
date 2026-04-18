# Pong-style paddle. Provides angled deflection for ball bounces.

extends UniversalBody

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Set collision shape size from exports
func _ready() -> void:
	super._ready()
	collision_shape.shape.size = Vector2(width, height)

# Draw white rectangle
func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), Color.WHITE)
