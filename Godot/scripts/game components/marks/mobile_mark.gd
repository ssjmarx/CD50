## mark that follows a target CDEntity with lock-on behavior
class_name MobileMark extends CDMark

@export var follow_offset: Vector2 = Vector2.ZERO
@export var lerp_speed: float = 10.0

@export_group("Target")
@export var target_entity_path: NodePath = ""
@export var target_groups: Array[StringName] = []

var _target: CDEntity

func _on_initialize() -> void:
	super._on_initialize()
	
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_target = node

## reuses existing target, or finds nearest valid target to current position
func _physics_process(delta: float) -> void:
	if _target and not is_instance_valid(_target):
		_target = null
	
	if not _target:
		_acquire_target()
	
	if _target:
		var target_pos := _target.global_position + follow_offset
		global_position = global_position.lerp(target_pos, lerp_speed * delta)

func _acquire_target() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, global_position)
		if candidate:
			_target = candidate
			return
