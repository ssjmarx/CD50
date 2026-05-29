# ImpulseReceiverGuts
# Applies external impulse forces to the parent entity
# Minimal adapter — listens for impulse signals and forwards to entity velocity

class_name ImpulseReceiverGuts extends CDEntityComponent

# --- exports ---

# signals providing an impulse vector (Vector2)
@export_group("Listen Signals")
@export var impulse_signals: Array[StringName] = [&"external_impulse"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect impulse listener
func _on_initialize() -> void:
	for sig in impulse_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_impulse)

# --- signal handlers ---

# add the impulse vector to entity velocity
func _on_impulse(impulse: Vector2) -> void:
	entity.request_velocity_add(impulse)

# --- cleanup ---

# disconnect impulse listener for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in impulse_signals:
		if entity.is_connected(sig, _on_impulse):
			entity.disconnect(sig, _on_impulse)