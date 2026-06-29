## damage_on_joust_arm.gd
## Produces: damage to a collider when this entity wins a comparative joust check (velocity/Y/custom).
## Consumes: collision signals; entity comparison properties; target_groups filter.
class_name DamageOnJoustArm extends CDEntityComponent

## which property to compare between self and collider
@export var comparison_mode: CDEnums.EntityCompare = CDEnums.EntityCompare.VELOCITY

## multiplier for velocity-based damage scaling
@export var velocity_damage_scale: float = 0.01

## minimum damage dealt on a successful joust
@export var minimum_damage: int = 1

## tolerance range for tie detection
@export var comparison_tolerance: float = 0.0

## what to do on a tie (within tolerance)
@export var tiebreaker: CDEnums.EntityCompareTiebreaker = CDEnums.EntityCompareTiebreaker.DONT_FIRE

## what to do when a comparison property is missing
@export var invalid_action: CDEnums.EntityCompareInvalidAction = CDEnums.EntityCompareInvalidAction.DONT_FIRE

## property name for CUSTOM comparison mode
@export var custom_property_name: StringName = &""

## if non-empty, only damage colliders in these groups
@export var target_groups: Array[StringName]

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

## connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

## compare self vs collider and deal damage if self wins
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	var self_value: Variant = _read_compare_value(entity)
	var collider_value: Variant = _read_compare_value(collider)

	## handle missing properties
	if self_value == null or collider_value == null:
		if invalid_action == CDEnums.EntityCompareInvalidAction.FIRE:
			_deal_damage(collider, minimum_damage)
		return

	var diff := float(self_value) - float(collider_value)

	## handle tie (within tolerance)
	if absf(diff) <= comparison_tolerance:
		if tiebreaker == CDEnums.EntityCompareTiebreaker.FIRE:
			_deal_damage(collider, minimum_damage)
		return

	if _self_wins(diff):
		_deal_damage(collider, _calculate_damage(diff))

## determine if self wins the comparison (Y_POSITION is inverted)
func _self_wins(diff: float) -> bool:
	if comparison_mode == CDEnums.EntityCompare.Y_POSITION:
		return diff < 0.0
	return diff > 0.0

## calculate damage based on difference and mode
func _calculate_damage(diff: float) -> int:
	if comparison_mode == CDEnums.EntityCompare.VELOCITY:
		return maxi(int(absf(diff) * velocity_damage_scale), minimum_damage)
	return minimum_damage

## emit damage signals on the collider
func _deal_damage(collider: CDEntity, damage_amount: int) -> void:
	for key in damage_keys:
		collider.blackboard[key] = damage_amount
	for key in source_keys:
		collider.blackboard[key] = entity
	for sig in damage_signals:
		collider.bus_emit(sig)

## read the comparison value from an entity based on mode
func _read_compare_value(ent: CDEntity) -> Variant:
	match comparison_mode:
		CDEnums.EntityCompare.VELOCITY:
			return ent.velocity.length()
		CDEnums.EntityCompare.Y_POSITION:
			return ent.global_position.y
		CDEnums.EntityCompare.CUSTOM:
			return _read_custom_property(ent)
	return null

## search entity and its children for the custom property
func _read_custom_property(ent: CDEntity) -> Variant:
	var val = ent.get(custom_property_name)
	if val != null:
		return val
	for child in ent.get_children():
		val = child.get(custom_property_name)
		if val != null:
			return val
	return null

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
