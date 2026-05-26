## instantly kills the collider based on a comparative property check — bypasses health pipeline
class_name DeathOnJoustArm extends CDEntityComponent

@export var comparison_mode: CDEnums.EntityCompare = CDEnums.EntityCompare.VELOCITY
@export var comparison_tolerance: float = 0.0
@export var tiebreaker: CDEnums.EntityCompareTiebreaker = CDEnums.EntityCompareTiebreaker.DONT_FIRE
@export var invalid_action: CDEnums.EntityCompareInvalidAction = CDEnums.EntityCompareInvalidAction.DONT_FIRE
@export var custom_property_name: StringName = &""
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

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
	
	var self_value: Variant = _read_compare_value(entity)
	var collider_value: Variant = _read_compare_value(collider)
	
	# invalid comparison — property not found
	if self_value == null or collider_value == null:
		if invalid_action == CDEnums.EntityCompareInvalidAction.FIRE:
			collider.emit_signal("request_deactivate")
		return
	
	var diff := float(self_value) - float(collider_value)
	
	# tie — within tolerance
	if absf(diff) <= comparison_tolerance:
		if tiebreaker == CDEnums.EntityCompareTiebreaker.FIRE:
			collider.emit_signal("request_deactivate")
		return
	
	# self wins comparison
	if _self_wins(diff):
		collider.emit_signal("request_deactivate")

func _self_wins(diff: float) -> bool:
	if comparison_mode == CDEnums.EntityCompare.Y_POSITION:
		return diff < 0.0
	return diff > 0.0

func _read_compare_value(ent: CDEntity) -> Variant:
	match comparison_mode:
		CDEnums.EntityCompare.VELOCITY:
			return ent.velocity.length()
		CDEnums.EntityCompare.Y_POSITION:
			return ent.global_position.y
		CDEnums.EntityCompare.CUSTOM:
			return _read_custom_property(ent)
	return null

func _read_custom_property(ent: CDEntity) -> Variant:
	var val = ent.get(custom_property_name)
	if val != null:
		return val
	for child in ent.get_children():
		val = child.get(custom_property_name)
		if val != null:
			return val
	return null

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
