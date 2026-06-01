# ShapeColliderGuts
# Overrides CDEntity's collision shape on setup and updates it on signal
# Reads polygon points from entity blackboard when triggered
# Supports static polygon points or dynamic shape updates from other components

class_name ShapeColliderGuts extends CDEntityComponent

# --- exports ---

# static polygon points for the collision shape (set at init if non-empty)
@export var static_points: PackedVector2Array

@export_group("Blackboard Keys")
# key to read polygon points from (PackedVector2Array)
@export var shape_key: StringName = &"shape_points"

# signals that trigger a shape update from blackboard
@export_group("Listen Signals")
@export var shape_signals: Array[StringName] = [&"shape_changed"]

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in shape_signals:
		entity.bus_connect(sig, _on_shape_changed)
	
	# apply static collision shape if configured
	if static_points.size() > 0:
		entity.set_collision_polygon(static_points)

# --- signal handlers ---

# read shape points from blackboard and apply to collision polygon
func _on_shape_changed() -> void:
	var points: PackedVector2Array = entity.blackboard.get(shape_key, PackedVector2Array())
	if points.size() > 0:
		entity.set_collision_polygon(points)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in shape_signals:
		entity.bus_disconnect(sig, _on_shape_changed)