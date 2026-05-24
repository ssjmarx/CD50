## flushes collisions after all movement is complete
class_name CDCollisionBuffer extends Node

var _entities_to_flush: Array[CDEntity] = []

func _ready() -> void:
	process_physics_priority = 35

func _physics_process(_delta: float) -> void:
	for entity in _entities_to_flush:
		if is_instance_valid(entity):
			entity.flush_collisions()
	_entities_to_flush.clear()

func register_entity(entity: CDEntity) -> void:
	_entities_to_flush.append(entity)
