## death_on_hit_arm.gd
## Produces: instant kill of a valid collider on collision (bypasses the health pipeline).
## Consumes: collision signals; target_groups filter.
class_name DeathOnHitArm extends CDEntityComponent

## if non-empty, only kill colliders in these groups
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## kill the collider if it's a valid target
func _on_collision(collider: Node, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	collider.emit_signal("request_deactivate")

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
