# AIFormationBrain
# Emits move_to positions maintaining an offset from a leader entity
# Auto-acquires leader from target groups if not set via NodePath

class_name AIFormationBrain extends CDEntityComponent

# direct NodePath to leader (optional — falls back to group search)
@export var target_entity_path: NodePath = ""

# groups to search if no direct path is set
@export var target_groups: Array[StringName] = [&"leader"]

# position offset from the leader (rotated by leader's facing)
@export var offset: Vector2 = Vector2(20, 0)

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]

# cached reference to the leader entity
var _leader: CDEntity

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure move_to signals exist and try to resolve leader from NodePath
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_leader = node

# emit move_to for the leader's position + rotated offset
func _physics_process(_delta: float) -> void:
	# invalidate leader if it's been freed
	if _leader and not is_instance_valid(_leader):
		_leader = null

	# try to acquire a new leader from target groups
	if not _leader:
		_acquire_leader()

	if not _leader:
		return

	# compute formation position: leader position + offset rotated by leader facing
	var target_pos := _leader.global_position + offset.rotated(_leader.global_rotation)
	for sig in move_signals:
		entity.emit_signal(sig, target_pos)

# search target groups for the nearest leader candidate
func _acquire_leader() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			_leader = candidate
			return

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_leader = null
