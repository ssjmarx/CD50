## points_guts.gd
## Produces: value_key + delta_key entries on the entity blackboard.
## Consumes: nothing (pure data holder seeded from @export points).

class_name PointsGuts extends CDEntityComponent

## --- exports ---

## point value awarded when this entity is destroyed
@export var points: int = 100

@export_group("Blackboard Keys")
@export var value_key: StringName = &"points"
@export var delta_key: StringName = &"points_delta"

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Seed the blackboard with the configured point value and a zero delta.
func _on_initialize() -> void:
	entity.blackboard[value_key] = points
	entity.blackboard[delta_key] = 0

## Erase the value/delta blackboard entries on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.blackboard.erase(value_key)
	entity.blackboard.erase(delta_key)
