# DieAtZeroHealthGuts
# Kills the entity when health reaches zero
# Bridges HealthpoolGuts' zero_health signal to entity deactivation

class_name DieAtZeroHealthGuts extends CDEntityComponent

# --- exports ---

# signals that indicate health has reached zero
@export_group("Listen Signals")
@export var zero_health_signals: Array[StringName] = [&"zero_health"]

# signals emitted to request entity deactivation
@export_group("Emit Signals")
@export var death_signals: Array[StringName] = [&"request_deactivate"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect zero_health listener and ensure death signals exist
func _on_initialize() -> void:
	for sig in zero_health_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_zero_health)
	for sig in death_signals:
		entity.ensure_signal(sig)

# --- signal handlers ---

# emit death signals to trigger entity deactivation
func _on_zero_health() -> void:
	for sig in death_signals:
		entity.emit_signal(sig)

# --- cleanup ---

# disconnect zero_health listener for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in zero_health_signals:
		if entity.is_connected(sig, _on_zero_health):
			entity.disconnect(sig, _on_zero_health)
