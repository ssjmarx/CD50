## player_move_brain.gd
## Produces: move direction (written to blackboard) in response to player input_router move signals.
## Consumes: game.input_router input_move signal (filtered by player_id); move_key blackboard key.
class_name PlayerMoveBrain extends CDEntityComponent

@export var player_id: int = 1
@export var move_key: StringName = &"move_direction"

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## Connect the input router's move signal during initialization.
func _on_initialize() -> void:
	game.input_router.input_move.connect(_on_input_move)

## Write the move direction to the blackboard when the matching player moves.
func _on_input_move(pid: int, direction: Vector2) -> void:
	if pid != player_id:
		return
	entity.blackboard[move_key] = direction

## Disconnect the move signal on deactivation (guarded with is_connected).
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_move.is_connected(_on_input_move):
			game.input_router.input_move.disconnect(_on_input_move)
