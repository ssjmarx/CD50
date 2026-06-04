## MobileMark
## Area2D mark that follows a target entity with lerp-based smooth movement
## Supports explicit NodePath targeting or auto-acquire nearest from groups

class_name MobileMark extends CDMark

## --- exports ---

## offset from target's global position
@export var follow_offset: Vector2 = Vector2.ZERO
## lerp speed for smooth following (higher = tighter)
@export var lerp_speed: float = 10.0

## target configuration: explicit path or auto-acquire from groups
@export_group("Target")
@export var target_entity_path: NodePath = ""
@export var target_groups: Array[StringName] = []

## --- state ---

## the entity this mark is currently following
var _target: CDEntity

## --- lifecycle ---

## resolve explicit target from NodePath
func _on_initialize() -> void:
	super._on_initialize()
	
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_target = node

## --- processing ---

## follow target or acquire a new one each physics frame
func _physics_process(delta: float) -> void:
	if _target and not is_instance_valid(_target):
		_target = null
	
	if not _target:
		_acquire_target()
	
	if _target:
		var target_pos := _target.global_position + follow_offset
		global_position = global_position.lerp(target_pos, lerp_speed * delta)

## --- target acquisition ---

## find nearest valid entity from target groups
func _acquire_target() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, global_position)
		if candidate:
			_target = candidate
			return
