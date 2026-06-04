## PlayerMoveBrain
## Converts player directional input into blackboard entries
## Filters by player_id for multiplayer support

class_name PlayerMoveBrain extends CDEntityComponent

@export var player_id: int = 1
@export var move_key: StringName = &"move_direction"

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## on initialize
func _on_initialize() -> void:
	game.input_router.input_move.connect(_on_input_move)

## on input move
func _on_input_move(pid: int, direction: Vector2) -> void:
	if pid != player_id:
		return
	entity.blackboard[move_key] = direction

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_move.is_connected(_on_input_move):
			game.input_router.input_move.disconnect(_on_input_move)
