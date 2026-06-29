## StaticFrictionLeg
## Produces: a constant deceleration velocity request (uniform braking force).
## Consumes: entity current linear velocity.

class_name FrictionStatic extends CDEntityComponent

## --- exports ---

## deceleration in pixels per second squared
@export var deceleration: float = 100.0

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## apply constant braking force, snap to zero if braking would overshoot
func _physics_process(delta: float) -> void:
	var vel := entity.velocity
	if vel == Vector2.ZERO:
		return
	var speed := vel.length()
	var brake_force := deceleration * delta
	
	## snap to zero to prevent velocity sign flip
	if brake_force >= speed:
		entity.request_velocity_add(-vel)
	else:
		entity.request_velocity_add(-vel.normalized() * brake_force)