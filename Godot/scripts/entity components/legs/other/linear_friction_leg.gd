## LinearFrictionLeg
## Produces: a speed-proportional deceleration velocity request (linear friction).
## Consumes: entity current linear velocity.

class_name LinearFrictionLeg extends CDEntityComponent

## --- exports ---

## maximum friction force at max_speed (pixels per second squared)
@export var max_friction: float = 800.0
## speed at which friction reaches maximum
@export var max_speed: float = 300.0

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## apply friction proportional to current speed each frame
func _physics_process(delta: float) -> void:
	var vel := entity.velocity
	var speed := vel.length()
	if speed == 0.0:
		return
	
	var t := clampf(speed / max_speed, 0.0, 1.0)
	var friction_force := max_friction * t
	entity.request_velocity_add(-vel.normalized() * friction_force * delta)
