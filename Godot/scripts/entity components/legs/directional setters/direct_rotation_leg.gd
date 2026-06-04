## DirectRotationLeg
## Tank-style continuous rotation from move_direction.x polled on the entity blackboard
## Positive x = rotate clockwise, negative x = rotate counter-clockwise

class_name DirectRotationLeg extends CDEntityComponent

## --- exports ---

## rotation speed in degrees per second
@export var rotation_speed: float = 180.0

@export_group("Blackboard Keys")
## key to read move direction from (Vector2 — uses x component as spin: -1 to 1)
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

## read move_direction.x as spin, apply as angular velocity
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	var spin: float = direction.x
	if spin != 0.0:
		var radians_per_sec := deg_to_rad(rotation_speed)
		entity.request_angular_set(spin * radians_per_sec)
	else:
		entity.request_angular_set(0.0)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()