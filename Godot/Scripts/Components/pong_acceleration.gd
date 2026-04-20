# Pong-style acceleration. Ramps velocity through discrete levels on paddle collision.

extends UniversalComponent

# Acceleration configuration
@export var acceleration_factor: float = 1.2
@export var acceleration_levels: int = 8
@export var target_group: String = "paddles"

var current_acceleration_level: int = 1

# Connect to parent's collision signal
func _ready() -> void:
	parent.body_collided.connect(accelerate)

# Multiply velocity by the acceleration factor when hitting a target group member, up to the level cap
func accelerate(collider: Node, _normal: Vector2) -> void:
	if collider.is_in_group(target_group):
		if current_acceleration_level < acceleration_levels:
			parent.velocity = parent.velocity * acceleration_factor
			current_acceleration_level += 1