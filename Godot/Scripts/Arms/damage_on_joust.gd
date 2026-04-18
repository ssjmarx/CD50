extends UniversalComponent

@export var damage_amount: int = 1
@export var tie_breaker: Tie = Tie.NO_DAMAGE

enum Tie { 
	BOTH_DAMAGE, 
	NO_DAMAGE 
	}

func _ready() -> void:
	parent.body_collided.connect(_on_collision)

func _on_collision(collider, _normal) -> void:
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
