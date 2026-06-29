## AccelerationMovementLeg
## Produces: a directional acceleration velocity request that builds momentum over time.
## Consumes: entity.blackboard["move_direction"].

class_name AccelerationLeg extends CDEntityComponent

## --- exports ---

## acceleration magnitude in pixels per second squared
@export var acceleration: float = 800.0

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

## add acceleration force in the polled direction each frame
func _physics_process(delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction != Vector2.ZERO:
		entity.request_velocity_add(direction.normalized() * acceleration * delta)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()