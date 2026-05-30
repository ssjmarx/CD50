# MoveAdapterGuts
# Converts "move_to" target positions into "move" direction vectors
# Pure signal translator — bridges Brains that emit targets to Legs that expect directions

class_name MoveAdapterGuts extends CDEntityComponent

# --- exports ---

# signals providing a target position (Vector2)
@export_group("Listen Signals")
@export var target_signals: Array[StringName] = [&"move_to"]

# emitted with direction vector from entity to target (Vector2)
@export_group("Emit Signals")
@export var direction_signals: Array[StringName] = [&"move"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect target listener and ensure direction signal exists
func _on_initialize() -> void:
	for sig in target_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_target)
	for sig in direction_signals:
		entity.ensure_signal(sig)

# --- signal handlers ---

# calculate direction from entity position to target and emit as move
func _on_target(target: Vector2) -> void:
	var direction := entity.global_position.direction_to(target)
	for sig in direction_signals:
		entity.emit_signal(sig, direction)

# --- cleanup ---

# disconnect target listener for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in target_signals:
		if entity.is_connected(sig, _on_target):
			entity.disconnect(sig, _on_target)
