# UFO entity with configurable hitbox. Behavior defined by attached Legs and Brains components.

extends UniversalBody

@onready var collision_shape: CollisionShape2D = $CollisionShape2D # Physics collider

# Set collision shape size from exports
func _ready() -> void:
	super._ready()
	collision_shape.shape.size = Vector2(width, height)
