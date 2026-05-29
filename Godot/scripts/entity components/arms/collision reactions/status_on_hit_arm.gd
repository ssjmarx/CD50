# StatusEffectArm
# Sends a status effect signal and duration to another entity on collision
# Emits apply_status(status_name, duration) on the collider

class_name StatusEffectArm extends CDEntityComponent

# name of the status effect to apply (e.g. "stun", "slow")
@export var status_name: StringName = &"stun"

# duration of the status effect in seconds
@export var duration: float = 2.0

# if non-empty, only apply to colliders in these groups
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var status_signals: Array[StringName] = [&"apply_status"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

# apply status effect to the collider if it's a valid target
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	for sig in status_signals:
		if collider.has_signal(sig):
			collider.emit_signal(sig, status_name, duration)

# return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

# disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)