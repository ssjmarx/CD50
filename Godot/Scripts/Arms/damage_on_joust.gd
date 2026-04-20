# Joust-style combat: the faster entity deals damage on collision.
# Supports tie-breaking behavior for equal-speed collisions.

extends UniversalComponent

# Joust configuration
@export var damage_amount: int = 1
@export var tie_breaker: Tie = Tie.NO_DAMAGE

enum Tie { 
	BOTH_DAMAGE, 
	NO_DAMAGE 
	}

# Connect to parent's collision signal
func _ready() -> void:
	parent.body_collided.connect(_on_collision)

# Compare velocities on collision — faster entity wins
func _on_collision(collider: Node, _normal: Vector2) -> void:
	if parent.velocity.length() > collider.velocity.length():
		collider.get_node("Health").reduce_health(damage_amount)
		return
	elif parent.velocity.length() == collider.velocity.length():
		match tie_breaker:
			Tie.BOTH_DAMAGE:
				collider.get_node("Health").reduce_health(damage_amount)
				return
			Tie.NO_DAMAGE:
				return