## cd_collision_buffer.gd
## Produces: flushed collision signals after all entity physics completes.
## Consumes: CDEntity registrations of pending collisions.
class_name CDCollisionBuffer extends Node

## entities that had collisions this frame and need their signals flushed
var _entities_to_flush: Array[CDEntity] = []

## Set fixed priority 35 — right after entity physics.
func _ready() -> void:
	process_physics_priority = 35

## Flush all registered entities, then clear the list.
func _physics_process(_delta: float) -> void:
	for entity in _entities_to_flush:
		if is_instance_valid(entity):
			entity.flush_collisions()
	_entities_to_flush.clear()

## Called by CDEntity when it detects collisions during its physics step.
func register_entity(entity: CDEntity) -> void:
	_entities_to_flush.append(entity)