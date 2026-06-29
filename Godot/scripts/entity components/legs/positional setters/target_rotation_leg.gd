## TargetRotationLeg
## Produces: an angular velocity request that faces the move_direction vector.
## Consumes: entity.blackboard["move_direction"].

class_name TargetRotationLeg extends CDEntityComponent

## --- exports ---

## rotation speed in degrees per second (0 or below = instant snap)
@export var rotation_speed: float = 360.0

@export_group("Blackboard Keys")
## key to read move direction from (Vector2 — rotates to face this direction)
@export var direction_key: StringName = &"move_direction"

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## on initialize
func _on_initialize() -> void:
	pass

## --- processing ---

## poll move_direction, rotate to face it
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction == Vector2.ZERO:
		return
	
	var target_angle := direction.angle()
	var current := entity.global_rotation
	var angle_diff := angle_difference(current, target_angle)
	
	if rotation_speed <= 0.0:
		entity.request_rotation_set(target_angle)
	else:
		## smooth rotation with overshoot prevention
		var max_step := deg_to_rad(rotation_speed) * get_physics_process_delta_time()
		if absf(angle_diff) <= max_step:
			entity.request_rotation_set(target_angle)
		else:
			entity.request_rotation_set(current + signf(angle_diff) * max_step)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()