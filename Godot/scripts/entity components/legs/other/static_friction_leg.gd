## StaticFrictionLeg
## Constant deceleration that brings velocity to zero
## Applies uniform braking force regardless of speed, snaps to zero to prevent jitter

class_name FrictionStatic extends CDEntityComponent

## --- exports ---

## deceleration in pixels per second squared
@export var deceleration: float = 100.0

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## --- processing ---

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
