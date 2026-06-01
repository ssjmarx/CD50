# ImpulseReceiverGuts
# Applies external impulse forces to the parent entity
# Reads impulse vector from entity blackboard on signal trigger

class_name ImpulseReceiverGuts extends CDEntityComponent

# --- exports ---

@export_group("Blackboard Keys")
# key to read impulse vector from (Vector2)
@export var impulse_key: StringName = &"external_impulse"

# signals that trigger an impulse application
@export_group("Listen Signals")
@export var impulse_signals: Array[StringName] = [&"external_impulse"]

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in impulse_signals:
		entity.bus_connect(sig, _on_impulse)

# --- signal handlers ---

# read impulse from blackboard and add to entity velocity
func _on_impulse() -> void:
	var impulse: Vector2 = entity.blackboard.get(impulse_key, Vector2.ZERO)
	if impulse != Vector2.ZERO:
		entity.request_velocity_add(impulse)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in impulse_signals:
		entity.bus_disconnect(sig, _on_impulse)