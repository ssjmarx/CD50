## AI that emits a movement direction orbiting a CDEntity with lock-on behavior
class_name AIOrbitBrain extends CDEntityComponent

@export var orbit_radius: float = 50.0
@export var orbit_speed: float = 2.0
@export var update_interval: float = 0.0
@export var targeting_noise: float = 0.0

@export_group("Target")
@export var target_entity_path: NodePath = ""
@export var target_groups: Array[StringName] = [&"leader"]

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]

var _leader: CDEntity
var _elapsed: float = 0.0
var _update_timer: float = 0.0
var _last_target_pos: Vector2 = Vector2.ZERO

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

func _physics_process(delta: float) -> void:
	_elapsed += delta
	
	if _leader and not is_instance_valid(_leader):
		_leader = null
	
	if not _leader:
		_acquire_leader()
	
	if not _leader:
		return
	
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			for sig in move_signals:
				entity.emit_signal(sig, _last_target_pos)
			return
		_update_timer = 0.0
	
	var leader_pos := _apply_noise(_leader.global_position)
	var angle := _elapsed * orbit_speed
	var offset := Vector2(cos(angle), sin(angle)) * orbit_radius
	_last_target_pos = leader_pos + offset
	for sig in move_signals:
		entity.emit_signal(sig, _last_target_pos)

func _acquire_leader() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			_leader = candidate
			return

func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_leader = null
	_elapsed = 0.0
	_update_timer = 0.0
	_last_target_pos = Vector2.ZERO
