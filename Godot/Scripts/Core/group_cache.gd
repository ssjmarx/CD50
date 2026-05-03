# Lazy dirty-flag cache for group node lookups. Avoids repeated get_nodes_in_group() allocations.
# Mark groups dirty when nodes enter/exit the tree or add_to_group() is called.

extends Node

var _cache: Dictionary = {}     # {group_name: Array[Node]}
var _dirty: Dictionary = {}     # {group_name: bool}

func mark_dirty(group_name: String) -> void:
	_dirty[group_name] = true

func get_group(group_name: String) -> Array:
	if _dirty.get(group_name, true):
		_cache[group_name] = get_tree().get_nodes_in_group(group_name)
		_dirty[group_name] = false
	return _cache[group_name]

func get_count(group_name: String) -> int:
	return get_group(group_name).size()