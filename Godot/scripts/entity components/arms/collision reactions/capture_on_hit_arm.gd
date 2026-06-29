## capture_on_hit_arm.gd
## Produces: a lasso-capture payload on collision (writes capture data, emits capture/success/complete signals, cleans up the bullet).
## Consumes: entity.blackboard[captor_key]; collision signals; target_groups filter.
class_name CaptureOnHitArm extends CDEntityComponent

@export var target_groups: Array[StringName] = [&"player"]

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"captor"
@export var target_blackboard_key: StringName = &"captured_entity"
@export var captor_blackboard_key: StringName = &"captured_by"
@export var success_key: StringName = &"did_capture"

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals on Target")
@export var capture_signals: Array[StringName] = [&"player_captured"]

@export_group("Emit Signals on Captor")
@export var captor_success_signals: Array[StringName] = [&"capture_succeeded"]
@export var captor_complete_signals: Array[StringName] = [&"tractor_beam_complete"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## Connect each collision signal to the handler during initialization.
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## Apply the capture payload to a valid target: write blackboards, emit on target/captor buses, then deactivate the bullet.
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider) or not _is_valid_target(collider):
		return

	var captor = entity.blackboard.get(captor_key)
	if not is_instance_valid(captor):
		return

	## write capture data to game and target blackboards
	game.blackboard[target_blackboard_key] = collider
	collider.blackboard[captor_blackboard_key] = captor

	## emit capture signal on target's bus
	for sig in capture_signals:
		collider.bus_emit(sig)

	## emit success signal on captor's bus (for limit tracking in LassoBrain)
	for sig in captor_success_signals:
		captor.bus_emit(sig)

	## emit complete signal on captor's bus so it knows to end capture phase
	for sig in captor_complete_signals:
		captor.bus_emit(sig)

	## flag bullet as successful capture so it emits correct signals on cleanup
	entity.blackboard[success_key] = true

	## clean up bullet
	entity.deactivate()

## Return true if target_groups is empty or collider is in one of them.
func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

## Disconnect all collision signals on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)