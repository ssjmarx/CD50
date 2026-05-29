## converts "move_to" target positions into "move" direction vectors
class_name MoveAdapterGuts extends CDEntityComponent

@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

@export_group("Emit Signals")
@export var direction_signals: Array[StringName] = [&"move"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in target_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_target)
	for sig in direction_signals:
		entity.ensure_signal(sig)

func _on_target(target: Vector2) -> void:
	var direction := entity.global_position.direction_to(target)
	for sig in direction_signals:
		entity.emit_signal(sig, direction)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in target_signals:
		if entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
