## player_aim_brain.gd
## Produces: an aim direction (from entity toward mouse position) written to blackboard each frame.
## Consumes: viewport mouse position; aim_key blackboard key; entity.global_position.
class_name PlayerAimBrain extends CDEntityComponent

## which player this brain listens to (matches input router player_id)
@export var player_id: int = 1

@export var aim_key: StringName = &"aim_direction"

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## Write the aim direction (entity toward mouse) to the blackboard each frame.
func _physics_process(_delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos == Vector2.ZERO:
		return
	var direction = (mouse_pos - entity.global_position).normalized()
	entity.blackboard[aim_key] = direction

## Base deactivation hook (no extra cleanup needed).
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
