## per-type entity pool
class_name CDObjectPool extends Node

@export var scene: PackedScene

## smaller sizes than this aren't worth it to pool
@export var initial_size: int = 50
@export var grow_by: int = 5
@export var max_size: int = 0

var _available: Array[CDEntity] = []
var _active: Array[CDEntity] = []

## pre-warm the object pool with all of the desired entities
func _ready() -> void:
	for i in initial_size:
		var entity = _create_entity()
		_available.append(entity)

## method for spawners getting an entity from the pool
func acquire() -> CDEntity:
	if _available.is_empty():
		var grow_amount = grow_by
		if max_size > 0:
			var remaining = max_size - get_total_count()
			if remaining <= 0:
				return null
			grow_amount = mini(grow_amount, remaining)
		for i in grow_amount:
			_available.append(_create_entity())
	
	var entity = _available.pop_back()
	_active.append(entity)
	return entity

## method for dying pooled entities to go back to the pool
func release(entity: CDEntity) -> void:
	_active.erase(entity)
	_available.append(entity)

### query methods

func get_active_count() -> int:
	return _active.size()

func get_available_count() -> int:
	return _available.size()

func get_total_count() -> int:
	return _active.size() + _available.size()

## cleanup method
func _exit_tree() -> void:
	for entity in _active:
		entity.queue_free()
	for entity in _available:
		entity.queue_free()
	_active.clear()
	_available.clear()


### helper methods

func _create_entity() -> CDEntity:
	var entity: CDEntity = scene.instantiate()
	entity.pool = self
	add_child(entity)
	
	entity.set_physics_process(false)
	entity.visible = false
	_disable_collision_shapes(entity)
	return entity

func _disable_collision_shapes(entity: CDEntity) -> void:
	for child in entity.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
