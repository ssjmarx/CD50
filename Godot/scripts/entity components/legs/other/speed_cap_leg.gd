## speed_cap_leg.gd
## Produces: a velocity request enforcing a hard maximum speed limit.
## Consumes: entity current velocity.
class_name SpeedCapLeg extends CDEntityComponent

## --- exports ---

## maximum allowed speed in pixels per second
@export var max_speed: float = 400.0

## set component category to STEERING (priority 20)
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## clamp entity speed to max_speed each physics frame
func _physics_process(_delta: float) -> void:
	var vel := entity.velocity
	var speed := vel.length()
	if speed > max_speed:
		entity.request_velocity_set(vel.normalized() * max_speed)
