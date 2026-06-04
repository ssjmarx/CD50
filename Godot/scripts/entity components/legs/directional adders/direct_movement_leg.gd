## DirectMovementLeg
## Hard-sets velocity from direction polled on the entity blackboard
## Zeros velocity when no direction is found (no momentum drift)

class_name DirectMovementLeg extends CDEntityComponent

## --- exports ---

## movement speed in pixels per second
@export var speed: float = 200.0

@export_group("Blackboard Keys")
## key to read movement direction from (Vector2)
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

## set velocity to direction * speed, or zero if no direction on blackboard
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction != Vector2.ZERO:
		entity.request_velocity_set(direction.normalized() * speed)
	else:
		entity.request_velocity_set(Vector2.ZERO)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()