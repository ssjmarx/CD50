## overrides CDEntity's collision shape on setup and updates it on a signal
class_name ShapeColliderGuts extends CDEntityComponent

@export var static_points: PackedVector2Array

@export_group("Listen Signals")
@export var shape_signals: Array[StringName] = [&"shape_changed"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in shape_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_shape_changed)
	
	if static_points.size() > 0:
		entity.set_collision_polygon(static_points)

func _on_shape_changed(points: PackedVector2Array) -> void:
	entity.set_collision_polygon(points)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in shape_signals:
		if entity.is_connected(sig, _on_shape_changed):
			entity.disconnect(sig, _on_shape_changed)
