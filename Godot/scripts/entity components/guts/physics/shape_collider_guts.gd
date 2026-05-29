# ShapeColliderGuts
# Overrides CDEntity's collision shape on setup and updates it on signal
# Supports static polygon points or dynamic shape updates from other components

class_name ShapeColliderGuts extends CDEntityComponent

# --- exports ---

# static polygon points for the collision shape (set at init if non-empty)
@export var static_points: PackedVector2Array

# signals providing updated polygon points (PackedVector2Array)
@export_group("Listen Signals")
@export var shape_signals: Array[StringName] = [&"shape_changed"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect shape listener, apply static points if provided
func _on_initialize() -> void:
	for sig in shape_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_shape_changed)
	
	# apply static collision shape if configured
	if static_points.size() > 0:
		entity.set_collision_polygon(static_points)

# --- signal handlers ---

# update the entity's collision polygon from signal data
func _on_shape_changed(points: PackedVector2Array) -> void:
	entity.set_collision_polygon(points)

# --- cleanup ---

# disconnect shape listener for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in shape_signals:
		if entity.is_connected(sig, _on_shape_changed):
			entity.disconnect(sig, _on_shape_changed)