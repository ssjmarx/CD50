## player_move_to_brain.gd
## Produces: move direction and distance toward the global mouse position (written to blackboard), stopping within a dead zone.
## Consumes: entity.get_global_mouse_position(); move_direction_key/move_distance_key blackboard keys.
class_name PlayerMoveToBrain extends CDEntityComponent

@export var dead_zone: float = 4.0

@export_group("Blackboard Keys")
@export var move_direction_key: StringName = &"move_direction"
@export var move_distance_key: StringName = &"move_distance"

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## Write direction/distance toward the mouse to the blackboard (zero within dead zone).
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := entity.get_global_mouse_position()
	var to_target := target - entity.global_position
	var distance := to_target.length()
	
	if distance <= dead_zone:
		entity.blackboard[move_direction_key] = Vector2.ZERO
		entity.blackboard[move_distance_key] = 0.0
		return
	
	entity.blackboard[move_direction_key] = to_target.normalized()
	entity.blackboard[move_distance_key] = distance

## Disable physics processing on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	set_physics_process(false)
