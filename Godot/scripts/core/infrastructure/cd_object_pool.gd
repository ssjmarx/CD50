# CDObjectPool
# Per-type entity pool — pre-warms instances to avoid runtime allocation
# Entities are created invisible with physics disabled, activated on acquire

class_name CDObjectPool extends Node

# the scene to instantiate for this pool
@export var scene: PackedScene

# pre-warm count, growth settings, and optional cap
@export var initial_size: int = 50
@export var grow_by: int = 5
@export var max_size: int = 0

# available (inactive) and active entity lists
var _available: Array[CDEntity] = []
var _active: Array[CDEntity] = []

# --- Setup ---

# pre-warm the pool with initial_size entities
func _ready() -> void:
	for i in initial_size:
		var entity = _create_entity()
		_available.append(entity)

# --- Acquire / Release ---

# get an entity from the pool, growing if needed
func acquire() -> CDEntity:
	# grow the pool if empty
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

# return an entity to the pool (called by CDEntity.deactivate)
func release(entity: CDEntity) -> void:
	_active.erase(entity)
	_available.append(entity)

# --- Query Methods ---

func get_active_count() -> int:
	return _active.size()

func get_available_count() -> int:
	return _available.size()

func get_total_count() -> int:
	return _active.size() + _available.size()

# --- Cleanup ---

# free all entities when the pool is removed from the tree
func _exit_tree() -> void:
	for entity in _active:
		entity.queue_free()
	for entity in _available:
		entity.queue_free()
	_active.clear()
	_available.clear()

# --- Internal ---

# instantiate a new entity, set its pool ref, disable it
func _create_entity() -> CDEntity:
	var entity: CDEntity = scene.instantiate()
	entity.pool = self
	add_child(entity)

	# start invisible and disabled until acquired
	entity.set_physics_process(false)
	entity.visible = false
	_disable_collision_shapes(entity)
	return entity

# disable all collision shapes on an entity
func _disable_collision_shapes(entity: CDEntity) -> void:
	for child in entity.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
