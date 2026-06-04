## CDCollisionBuffer
## Flushes collisions after all entity physics is complete
## Runs at priority 35 (after CDEntity at 30) to guarantee full move resolution

class_name CDCollisionBuffer extends Node

## entities that had collisions this frame and need their signals flushed
var _entities_to_flush: Array[CDEntity] = []

## fixed priority 35 — right after entity physics
func _ready() -> void:
	process_physics_priority = 35

## flush all registered entities, then clear the list
func _physics_process(_delta: float) -> void:
	for entity in _entities_to_flush:
		if is_instance_valid(entity):
			entity.flush_collisions()
	_entities_to_flush.clear()

## called by CDEntity when it detects collisions during its physics step
func register_entity(entity: CDEntity) -> void:
	_entities_to_flush.append(entity)
