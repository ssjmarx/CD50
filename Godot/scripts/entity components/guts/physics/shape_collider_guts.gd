## shape_collider_guts.gd
## Produces: collision-polygon updates driven by blackboard or a CDShape resource.
## Consumes: shape_key (entity blackboard); shape_changed signal.

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

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect the shape listener and apply the configured CDShape resource if present.
func _on_initialize() -> void:
	for sig in shape_signals:
		self.bus_connect(sig, _on_shape_changed)
	
	if shape_resource and shape_resource.points.size() > 0:
		entity.set_collision_polygon(shape_resource.points)

## --- signal handlers ---

## read shape points from blackboard and apply to collision polygon
func _on_shape_changed() -> void:
	var points: PackedVector2Array = entity.blackboard.get(shape_key, PackedVector2Array())
	if points.size() > 0:
		entity.set_collision_polygon(points)

## --- cleanup ---

## Disconnect the shape listener on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in shape_signals:
		self.bus_disconnect(sig, _on_shape_changed)
