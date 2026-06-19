## PointsGuts
## Data holder for an entity's point value
## Writes current value and delta to the entity blackboard for other components to read

class_name PointsGuts extends CDEntityComponent

## --- exports ---

## point value awarded when this entity is destroyed
@export var points: int = 100

@export_group("Blackboard Keys")
@export var value_key: StringName = &"points"
@export var delta_key: StringName = &"points_delta"

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## write initial value to blackboard
func _on_initialize() -> void:
	entity.blackboard[value_key] = points
	entity.blackboard[delta_key] = 0

## clear blackboard entries on deactivate
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.blackboard.erase(value_key)
	entity.blackboard.erase(delta_key)
