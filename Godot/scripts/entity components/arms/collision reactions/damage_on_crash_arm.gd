## damage_on_crash_arm.gd
## Produces: self-damage on collision (writes damage/source keys, emits take_damage on self).
## Consumes: collision signals; entity.blackboard; source_groups filter.
class_name DamageOnCrashArm extends CDEntityComponent

## amount of damage to deal to self
@export var damage_amount: int = 1

## if non-empty, only react to colliders in these groups
@export var source_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var damage_keys: Array[StringName] = [&"incoming_damage"]
@export var source_keys: Array[StringName] = [&"damage_source"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect collision signals and ensure damage signals exist
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)
	for sig in damage_signals:
		entity.ensure_signal(sig)

## damage self if the collider is a valid source
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not _is_valid_source(collider):
		return
	for key in damage_keys:
		entity.blackboard[key] = damage_amount
	for key in source_keys:
		entity.blackboard[key] = collider
	for sig in damage_signals:
		entity.bus_emit(sig)

## return true if source_groups is empty or collider is in one of them
func _is_valid_source(collider: CDEntity) -> bool:
	if source_groups.is_empty():
		return true
	if not is_instance_valid(collider):
		return false
	for group in source_groups:
		if collider.is_in_group(group):
			return true
	return false

## disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
