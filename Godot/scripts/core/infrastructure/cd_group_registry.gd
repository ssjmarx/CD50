## CDGroupRegistry
## Frame-cached, typed access to entity groups
## Runs at priority 5 (first thing each frame) to refresh dirty groups before anyone reads them

class_name CDGroupRegistry extends Node

## emitted when a group's entity count actually changes
signal group_count_changed(group_name: StringName, count: int)

## cached group memberships and dirty tracking
var _cache: Dictionary = {}         # {StringName: Array[CDEntity]}
var _dirty: Dictionary = {}         # {StringName: bool}
var _last_counts: Dictionary = {}   # {StringName: int}

## priority 5 — refresh before any component reads groups
func _ready() -> void:
	process_physics_priority = 5

## --- Frame Update ---

## refresh all dirty groups, then clear the dirty list
func _physics_process(_delta: float) -> void:
	for group_name in _dirty:
		if _dirty[group_name]:
			_refresh_group(group_name)
	_dirty.clear()

## --- Dirty Marking ---

## invalidate cache for a group (called when entities join/leave groups)
func mark_dirty(group_name: StringName) -> void:
	_dirty[group_name] = true

## --- Query API ---

## get all entities in a group (auto-refreshes if dirty)
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

## find closest entity in a group to another entity (excludes self)
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

## --- Internal ---

## refresh a group's cache and emit count change if applicable
func _refresh_group(group_name: StringName) -> void:
	## query Godot's group system and cast to typed array
	var nodes = get_tree().get_nodes_in_group(group_name)
	var typed: Array[CDEntity] = []
	typed.assign(nodes)
	_cache[group_name] = typed

	## emit signal only when count actually changes
	var new_count = typed.size()
	var old_count = _last_counts.get(group_name, -1)
	if new_count != old_count:
		_last_counts[group_name] = new_count
		group_count_changed.emit(group_name, new_count)
