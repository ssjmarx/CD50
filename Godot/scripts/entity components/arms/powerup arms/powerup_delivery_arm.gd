## powerup_delivery_arm.gd
## Produces: a powerup delivery payload on collision (writes powerup_id + source to collider blackboard, emits receive_powerup).
## Consumes: collision signals; powerup_id; target_groups filter.
class_name PowerUpDeliveryArm extends CDEntityComponent

## identifier for the powerup being delivered
@export var powerup_id: StringName = &"wingman"

## if non-empty, only deliver to colliders in these groups
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var powerup_id_key: StringName = &"powerup_id"
@export var source_entity_key: StringName = &"source_entity"

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var deliver_signals: Array[StringName] = [&"receive_powerup"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## Connect each collision signal to the delivery handler during initialization.
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## deliver powerup to a valid collider
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	## write data to blackboard, then emit zero-arg signal
	collider.blackboard[powerup_id_key] = powerup_id
	collider.blackboard[source_entity_key] = entity

	for sig in deliver_signals:
		if collider.has_signal(sig):
			collider.bus_emit(sig)

## return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

## disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
