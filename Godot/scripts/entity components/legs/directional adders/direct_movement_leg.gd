## DirectMovementLeg
## Produces: a velocity-set request from polled direction.
## Consumes: entity.blackboard["move_direction"], optionally ["move_distance"].

class_name DirectMovementLeg extends CDEntityComponent

## --- exports ---

## movement speed in pixels per second
@export var speed: float = 200.0

@export_group("Blackboard Keys")
## key to read movement direction from (Vector2)
@export var direction_key: StringName = &"move_direction"

## optional key to read remaining move distance from (float)
## if present, caps velocity so frame movement doesn't exceed this distance
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

## set velocity to direction * speed, or zero if no direction on blackboard
## optionally caps speed if we would overshoot the target distance this frame
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	
	if direction != Vector2.ZERO:
		var target_velocity: Vector2 = direction.normalized() * speed
		
		## cap frame distance so a fast mover can't overshoot a target
		if distance_key != &"" and entity.blackboard.has(distance_key):
			var max_distance: float = entity.blackboard[distance_key]
			var frame_distance: float = speed * _delta
			
			if frame_distance > max_distance and frame_distance > 0.0:
				## scale velocity to cover exactly max_distance this frame
				target_velocity = target_velocity * (max_distance / frame_distance)
				
		entity.request_velocity_set(target_velocity)
	else:
		entity.request_velocity_set(Vector2.ZERO)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
