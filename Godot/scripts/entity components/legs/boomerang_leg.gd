## applies a constant return force toward spawn position
class_name BoomerangLeg extends CDEntityComponent

@export var return_force: float = 5.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _physics_process(delta: float) -> void:
	var to_origin := entity._spawn_position - entity.global_position
	if to_origin == Vector2.ZERO:
		return
	entity.request_velocity_add(to_origin.normalized() * return_force * delta)
