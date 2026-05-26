## sends a status effect signal and duration to another entity on collision
class_name StatusEffectArm extends CDEntityComponent

@export var status_name: StringName = &"stun"
@export var duration: float = 2.0
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var status_signals: Array[StringName] = [&"apply_status"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	for sig in status_signals:
		if collider.has_signal(sig):
			collider.emit_signal(sig, status_name, duration)

func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
