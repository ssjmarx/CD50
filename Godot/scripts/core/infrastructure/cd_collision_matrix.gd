# CDCollisionMatrix
# Auto-configures physics layers from CDCollisionGroup resources
# Maps group names to layer bitmasks so components never touch layers directly

class_name CDCollisionMatrix extends Node

# one CDCollisionGroup per collision type (players, enemies, bullets, etc.)
@export var collision_groups: Array[CDCollisionGroup] = []

# internal maps: group name → layer bit, group name → combined mask
var _layer_map: Dictionary = {}  # group_name : layer bit value
var _mask_map: Dictionary = {}   # group_name : combined mask

# build maps on ready (also called explicitly by CDGame._ready)
func _ready() -> void:
	_build_maps()

# public entry point for CDGame to trigger a rebuild
func build_maps() -> void:
	_build_maps()

# convert collision_groups array into layer and mask lookup dictionaries
func _build_maps() -> void:
	if collision_groups.is_empty():
		return
	if collision_groups.size() > 32:
		return

	# assign each group a unique bit (1 << index)
	_layer_map.clear()
	_mask_map.clear()
	for i in range(collision_groups.size()):
		var group = collision_groups[i]
		_layer_map[group.group_name] = 1 << i

	# build mask by OR-ing all target group layers
	for group in collision_groups:
		var mask = 0
		for target_name in group.collides_with:
			if not _layer_map.has(target_name):
				continue
			mask |= _layer_map[target_name]
		_mask_map[group.group_name] = mask

# --- Public API ---

# resolve a group name to its layer bitmask (used by collision handler registration)
func get_layer_for_group(group_name: StringName) -> int:
	return _layer_map.get(group_name, 0)

# set collision_layer and collision_mask on any CollisionObject2D from its groups
func configure(node: CollisionObject2D) -> void:
	var layer = 0
	var mask = 0
	var source_groups := _get_groups_for(node)

	# combine layers and masks from all groups the node belongs to
	for group_name in source_groups:
		if not _layer_map.has(group_name):
			continue
		layer |= _layer_map[group_name]
		mask |= _mask_map[group_name]

	node.collision_layer = layer
	node.collision_mask = mask

# resolve the group source for a node (CDEntity export vs Godot built-in)
func _get_groups_for(node: CollisionObject2D) -> Array:
	if node is CDEntity:
		return node.groups
	return node.get_groups()
