## applies external impulse forces to parent entity
class_name ImpulseReceiverGuts extends CDEntityComponent

@export_group("Listen Signals")
@export var impulse_signals: Array[StringName] = [&"external_impulse"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in impulse_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_impulse)

func _on_impulse(impulse: Vector2) -> void:
	entity.request_velocity_add(impulse)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in impulse_signals:
		if entity.is_connected(sig, _on_impulse):
			entity.disconnect(sig, _on_impulse)
