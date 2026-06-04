## AccelerationTargetLeg
## Accelerates in move_direction, tapering force within slow_distance of target
## Adds force each frame (momentum), reads move_direction + move_distance

class_name AccelerationTargetLeg extends CDEntityComponent

## --- exports ---

## acceleration magnitude in pixels per second squared
@export var acceleration: float = 800.0
## begins tapering acceleration within this distance
@export var slow_distance: float = 100.0
## acceleration reaches zero at this distance
@export var stop_distance: float = 5.0

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

## add scaled acceleration force in move_direction each frame
func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	var distance: float = entity.blackboard.get(distance_key, 0.0)
	
	if distance <= stop_distance:
		return
	
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction == Vector2.ZERO:
		return
	
	## scale acceleration by distance (full at slow_distance, zero at stop_distance)
	var accel_factor := clampf(
		(distance - stop_distance) / (slow_distance - stop_distance),
		0.0, 1.0
	)
	
	entity.request_velocity_add(direction * acceleration * accel_factor * delta)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()