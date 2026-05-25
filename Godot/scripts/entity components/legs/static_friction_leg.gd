## constant deceleration until velocity reaches zero
class_name FrictionStatic extends CDEntityComponent

@export var deceleration: float = 100.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _physics_process(delta: float) -> void:
	var vel := entity.velocity
	if vel == Vector2.ZERO:
		return
	var speed := vel.length()
	var brake_force := deceleration * delta
	if brake_force >= speed:
		entity.request_velocity_add(-vel)  # snap to zero
	else:
		entity.request_velocity_add(-vel.normalized() * brake_force)
