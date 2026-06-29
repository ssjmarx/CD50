## BoomerangLeg
## Produces: a constant return-force velocity request toward the entity's spawn position.
## Consumes: nothing (autonomous).

class_name BoomerangLeg extends CDEntityComponent

## --- exports ---

## force pulling toward spawn each second
@export var return_force: float = 5.0

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## add force toward spawn position each frame
func _physics_process(delta: float) -> void:
	var to_origin := entity._spawn_position - entity.global_position
	if to_origin == Vector2.ZERO:
		return
	entity.request_velocity_add(to_origin.normalized() * return_force * delta)
