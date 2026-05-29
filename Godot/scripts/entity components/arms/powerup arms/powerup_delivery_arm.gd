# PowerUpDeliveryArm
# Delivers a powerup to whatever the entity collides with
# Emits receive_powerup(powerup_id, entity) on the collider

class_name PowerUpDeliveryArm extends CDEntityComponent

# identifier for the powerup being delivered
@export var powerup_id: StringName = &"wingman"

# if non-empty, only deliver to colliders in these groups
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var deliver_signals: Array[StringName] = [&"receive_powerup"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

# deliver powerup to a valid collider
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	# emit receive_powerup on the collider
	for sig in deliver_signals:
		if collider.has_signal(sig):
			collider.emit_signal(sig, powerup_id, entity)

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
