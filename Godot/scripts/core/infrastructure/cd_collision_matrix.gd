## auto-configures physics layers from CDCollisionGroup resources.
class_name CDCollisionMatrix extends Node

@export var collision_groups: Array[CDCollisionGroup] = []

var _layer_map: Dictionary = {}  # group_name : layer bit value
var _mask_map: Dictionary = {}   # group_name : combined mask

func _ready() -> void:
	if collision_groups.is_empty():
		return
	
	# fail fast if misconfigured beyond godot's limit
	if collision_groups.size() > 32:
		push_error("CDCollisionMatrix: %d groups defined, but Godot supports a maximum of 32 physics layers. Remove a CDCollisionGroup or merge groups that share collision behavior." % collision_groups.size())
		return
	
	# dont ask me how bit shifting works i copied this from a thing
	for i in range(collision_groups.size()):
		var group = collision_groups[i]
		_layer_map[group.group_name] = 1 << i
	
	for group in collision_groups:
		var mask = 0
		for target_name in group.collides_with:
			if not _layer_map.has(target_name):
				push_error("CDCollisionMatrix: group '%s' lists unknown target '%s' in collides_with." % [group.group_name, target_name])
				continue
			mask |= _layer_map[target_name]
		_mask_map[group.group_name] = mask

## returns the layer bit value for a collision group name.
## used by CDEntity to resolve group-based handler registration to bitmasks.
func get_layer_for_group(group_name: StringName) -> int:
	return _layer_map.get(group_name, 0)

## sets collision_layer and collision_mask on CDEntity
func configure(entity: CDEntity) -> void:
	var layer = 0
	var mask = 0
	
	for group_name in entity.groups:
		if not _layer_map.has(group_name):
			continue
		layer |= _layer_map[group_name]
		mask |= _mask_map[group_name]
	
	entity.collision_layer = layer
	entity.collision_mask = mask
