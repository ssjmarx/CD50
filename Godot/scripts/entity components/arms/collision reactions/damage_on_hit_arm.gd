## damage_on_hit_arm.gd
## Produces: flat damage to colliders (writes damage/source keys, emits take_damage on the target).
## Consumes: collision signals; target_groups filter.
class_name DamageOnHitArm extends CDEntityComponent

## amount of damage to deal to the collider
@export var damage_amount: int = 1

## if non-empty, only damage colliders in these groups
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var damage_keys: Array[StringName] = [&"health_delta"]
@export var source_keys: Array[StringName] = [&"damage_source"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var damage_signals: Array[StringName] = [&"take_damage"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## damage the collider if it's a valid target and has the signal
func _on_collision(collider: Node, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	for key in damage_keys:
		collider.blackboard[key] = damage_amount
	for key in source_keys:
		collider.blackboard[key] = entity
	for sig in damage_signals:
		collider.bus_emit(sig)

## return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: Node) -> bool:
	if not collider is CDEntity:
		return false
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
