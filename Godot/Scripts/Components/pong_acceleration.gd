# Pong-style acceleration. Ramps velocity through 8 levels on paddle/ball collision.

extends UniversalComponent

@export var acceleration_factor: float = 1.2
@export var acceleration_levels: int = 8
@export var target_group: String = "paddles"

var current_acceleration_level: int = 1


# signal connections
func _ready() -> void:
	parent.body_collided.connect(accelerate)

# Increase speed to next level and emit signal
func accelerate(collider: Node, _normal: Vector2) -> void:
	if collider.is_in_group(target_group):
		if current_acceleration_level < acceleration_levels:
			parent.velocity = parent.velocity * acceleration_factor
			current_acceleration_level += 1