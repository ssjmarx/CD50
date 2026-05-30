# PlayerMoveToBrain
# Emits move_to with the mouse global position each physics frame
# Used for entities that follow the cursor (e.g., paddle in Pong)

class_name PlayerMoveToBrain extends CDEntityComponent

@export_group("Emit Signals")
@export var move_to_signals: Array[StringName] = [&"move_to"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure move_to signals exist on entity
func _on_initialize() -> void:
	for sig in move_to_signals:
		entity.ensure_signal(sig)

# emit mouse position as move_to target each frame
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := entity.get_global_mouse_position()
	for sig in move_to_signals:
		entity.emit_signal(sig, target)

# disable physics processing on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	set_physics_process(false)
