## kills the entity when health reaches zero
class_name DieAtZeroHealthGuts extends CDEntityComponent

@export_group("Listen Signals")
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

@export_group("Emit Signals")
@export var death_signals: Array[StringName] = [&"request_deactivate"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in zero_health_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_zero_health)
	for sig in death_signals:
		entity.ensure_signal(sig)

func _on_zero_health() -> void:
	for sig in death_signals:
		entity.emit_signal(sig)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in zero_health_signals:
		if entity.is_connected(sig, _on_zero_health):
			entity.disconnect(sig, _on_zero_health)
