## frame-cached, typed access to entity groups
class_name CDGroupRegistry extends Node

signal group_count_changed(group_name: StringName, count: int)

var _cache: Dictionary = {}         # {StringName: Array[CDEntity]}
var _dirty: Dictionary = {}         # {StringName: bool}
var _last_counts: Dictionary = {}   # {StringName: int}

func _ready() -> void:
	process_physics_priority = 5

## per frame cache update
func _physics_process(_delta: float) -> void:
	for group_name in _dirty:
		if _dirty[group_name]:
			_refresh_group(group_name)
	_dirty.clear()

## invalidate cache for a group
func mark_dirty(group_name: StringName) -> void:
	_dirty[group_name] = true

## get all entities in a group
func get_group(group_name: StringName) -> Array[CDEntity]:
	if _dirty.get(group_name, true):
		_refresh_group(group_name)
		_dirty.erase(group_name)
	return _cache.get(group_name, [])

## get count of entities in a group
func get_count(group_name: StringName) -> int:
	return get_group(group_name).size()

## find closest entity in a group to a world position
func get_nearest(group_name: StringName, to_pos: Vector2) -> CDEntity:
	var group = get_group(group_name)
	if group.is_empty():
		return null
	var nearest: CDEntity = null
	var nearest_dist_sq: float = INF
	for entity in group:
		var dist_sq = entity.global_position.distance_squared_to(to_pos)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = entity
	return nearest

## find closest entity in a group to another entity
func get_nearest_to_entity(group_name: StringName, entity: CDEntity) -> CDEntity:
	var group = get_group(group_name)
	if group.is_empty():
		return null
	var nearest: CDEntity = null
	var nearest_dist_sq: float = INF
	for candidate in group:
		if candidate == entity:
			continue
		var dist_sq = candidate.global_position.distance_squared_to(entity.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = candidate
	return nearest

## refresh a group's cache and emit count change if applicable
func _refresh_group(group_name: StringName) -> void:
	var nodes = get_tree().get_nodes_in_group(group_name)
	var typed: Array[CDEntity] = []
	typed.assign(nodes)
	_cache[group_name] = typed
	
	var new_count = typed.size()
	var old_count = _last_counts.get(group_name, -1)
	if new_count != old_count:
		_last_counts[group_name] = new_count
		group_count_changed.emit(group_name, new_count)
