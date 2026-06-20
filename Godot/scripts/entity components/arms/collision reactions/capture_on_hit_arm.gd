## CaptureOnHitArm
## Delivers the lasso payload on collision.
## Writes capture data to game blackboard, target blackboard, and emits the standard capture signals.
## Cleans up the bullet on successful hit.

class_name CaptureOnHitArm extends CDEntityComponent

@export var target_groups: Array[StringName] = [&"player"]

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"captor"
@export var target_blackboard_key: StringName = &"captured_entity"
@export var captor_blackboard_key: StringName = &"captured_by"
@export var success_key: StringName = &"did_capture"

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var capture_signals: Array[StringName] = [&"player_captured"]

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## apply capture to the collider if it's a valid target
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider) or not _is_valid_target(collider):
		return

	var captor = entity.blackboard.get(captor_key)
	if not is_instance_valid(captor):
		return

	# Write capture data to game and target blackboards
	game.blackboard[target_blackboard_key] = collider
	collider.blackboard[captor_blackboard_key] = captor

	# Emit capture signal on target's bus
	for sig in capture_signals:
		collider.bus_emit(sig)

	# Flag bullet as successful capture so it emits correct signals on cleanup
	entity.blackboard[success_key] = true

	# Clean up bullet
	entity.deactivate()

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
