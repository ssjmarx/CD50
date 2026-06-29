## ai_formation_brain.gd
## Produces: move direction and distance toward a leader's position plus a rotated offset (written to blackboard), auto-acquiring the leader from NodePath or target_groups.
## Consumes: leader via target_entity_path or target_groups (group_registry); move_key/distance_key blackboard keys.
class_name AIFormationBrain extends CDEntityComponent

## direct NodePath to leader (optional — falls back to group search)
@export var target_entity_path: NodePath = ""

## groups to search if no direct path is set
@export var target_groups: Array[StringName] = [&"leader"]

## position offset from the leader (rotated by leader's facing)
@export var offset: Vector2 = Vector2(20, 0)

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

## cached reference to the leader entity
var _leader: CDEntity

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## ensure move_to signals exist and try to resolve leader from NodePath
func _on_initialize() -> void:
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_leader = node

## emit move_to for the leader's position + rotated offset
func _physics_process(_delta: float) -> void:
	if _leader and not is_instance_valid(_leader):
		_leader = null

	if not _leader:
		_acquire_leader()

	if not _leader:
		return

	var target_pos := _leader.global_position + offset.rotated(_leader.global_rotation)
	var to_target = target_pos - entity.global_position
	
	entity.blackboard[move_key] = to_target.normalized()
	entity.blackboard[distance_key] = to_target.length()

## search target groups for the nearest leader candidate
func _acquire_leader() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			_leader = candidate
			return

## Clear the cached leader reference on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_leader = null
