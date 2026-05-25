## moves to an offset from a leader entity with target locking
class_name AIFormationBrain extends CDEntityComponent

@export var target_entity_path: NodePath = ""
@export var target_groups: Array[StringName] = [&"leader"]
@export var offset: Vector2 = Vector2(20, 0)

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]

var _leader: CDEntity

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_leader = node

func _physics_process(_delta: float) -> void:
	if _leader and not is_instance_valid(_leader):
		_leader = null
	
	if not _leader:
		_acquire_leader()
	
	if not _leader:
		return
	
	var target_pos := _leader.global_position + offset.rotated(_leader.global_rotation)
	for sig in move_signals:
		entity.emit_signal(sig, target_pos)

func _acquire_leader() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			_leader = candidate
			return

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_leader = null
