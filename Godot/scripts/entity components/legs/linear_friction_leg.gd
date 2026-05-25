## linearly scaling friction from 0 to top speed
class_name LinearFrictionLeg extends CDEntityComponent

@export var max_friction: float = 800.0
@export var max_speed: float = 300.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _physics_process(delta: float) -> void:
	var vel := entity.velocity
	var speed := vel.length()
	if speed == 0.0:
		return
	var t := clampf(speed / max_speed, 0.0, 1.0)
	var friction_force := max_friction * t
	entity.request_velocity_add(-vel.normalized() * friction_force * delta)
