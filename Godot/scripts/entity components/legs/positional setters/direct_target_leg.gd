## DirectTargetLeg
## Produces: a constant-speed velocity request along move_direction.
## Consumes: entity.blackboard move_direction + move_distance.

class_name DirectTargetLeg extends CDEntityComponent

## --- exports ---

## movement speed in pixels per second
@export var speed: float = 200.0
## distance threshold to consider arrived (stops and clears velocity)
@export var arrival_threshold: float = 2.0

@export_group("Blackboard Keys")
## key to read movement direction from (Vector2, normalized)
@export var direction_key: StringName = &"move_direction"
## key to read remaining distance from (float, pixels)
@export var distance_key: StringName = &"move_distance"

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## on initialize
func _on_initialize() -> void:
	pass

## --- processing ---

## set velocity in move_direction, stop when move_distance is consumed
func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	var distance: float = entity.blackboard.get(distance_key, 0.0)
	
	if distance <= arrival_threshold:
		entity.request_velocity_set(Vector2.ZERO)
		return
	
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction == Vector2.ZERO:
		return
	
	var step := speed * delta
	entity.request_velocity_set(direction * speed)
	
	var new_distance := maxf(0.0, distance - step)
	entity.blackboard[distance_key] = new_distance

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()