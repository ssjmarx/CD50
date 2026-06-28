## ShapeColliderGuts
## Overrides CDEntity's collision shape on setup and updates it on signal
## Reads polygon points from entity blackboard when triggered.
## Supports dynamic shape updates or a CDShape resource.

class_name ShapeColliderGuts extends CDEntityComponent

## --- exports ---

## a CDShape resource to use for the collision shape
@export var shape_resource: CDShape

@export_group("Blackboard Keys")
## key to read polygon points from (PackedVector2Array)
@export var shape_key: StringName = &"shape_points"

## signals that trigger a shape update from blackboard
@export_group("Listen Signals")
@export var shape_signals: Array[StringName] = [&"shape_changed"]

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in shape_signals:
		self.bus_connect(sig, _on_shape_changed)
	
	# Apply shape from resource if available
	if shape_resource and shape_resource.points.size() > 0:
		entity.set_collision_polygon(shape_resource.points)

## --- signal handlers ---

## read shape points from blackboard and apply to collision polygon
func _on_shape_changed() -> void:
	var points: PackedVector2Array = entity.blackboard.get(shape_key, PackedVector2Array())
	if points.size() > 0:
		entity.set_collision_polygon(points)

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in shape_signals:
		self.bus_disconnect(sig, _on_shape_changed)
