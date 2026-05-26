## instantly kills the entity itself when it collides with anything
class_name DeathOnCrashArm extends CDEntityComponent

@export var source_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not _is_valid_source(collider):
		return
	entity.emit_signal("request_deactivate")

func _is_valid_source(collider: CDEntity) -> bool:
	if source_groups.is_empty():
		return true
	if not is_instance_valid(collider):
		return false
	for group in source_groups:
		if collider.is_in_group(group):
			return true
	return false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
