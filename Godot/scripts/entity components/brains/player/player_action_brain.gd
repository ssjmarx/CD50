## player_action_brain.gd
## Produces: entity-bus signals (mapped action names and their "_end" variants) in response to player input_router action pressed/released events.
## Consumes: game.input_router input_action_pressed/released signals, filtered by player_id and action_mappings.
class_name PlayerActionBrain extends CDEntityComponent

@export var player_id: int = 1
@export var action_mappings: Array[StringName] = [&"fire"]

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## Connect the input router's action signals during initialization.
func _on_initialize() -> void:
	_connect_input_signals()

## Emit the mapped action on the entity bus when the matching player presses it.
func _on_action_pressed(pid: int, action: StringName) -> void:
	if pid != player_id or action not in action_mappings:
		return
	entity.bus_emit(action)

## Emit the mapped action's "_end" variant on the entity bus when the matching player releases it.
func _on_action_released(pid: int, action: StringName) -> void:
	if pid != player_id or action not in action_mappings:
		return
	entity.bus_emit(StringName(action + &"_end"))

## Disconnect input signals on sleep so the pooled entity stops reacting to input.
func _on_sleep() -> void:
	super._on_sleep()
	_disconnect_input_signals()

## Reconnect input signals on wake so the pooled entity resumes reacting to input.
func _on_wake() -> void:
	super._on_wake()
	_connect_input_signals()

## Disconnect input signals on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_disconnect_input_signals()

## Connect the input router's pressed/released signals (guarded against double-connects).
func _connect_input_signals() -> void:
	if is_instance_valid(game) and game.input_router:
		if not game.input_router.input_action_pressed.is_connected(_on_action_pressed):
			game.input_router.input_action_pressed.connect(_on_action_pressed)
		if not game.input_router.input_action_released.is_connected(_on_action_released):
			game.input_router.input_action_released.connect(_on_action_released)

## Disconnect the input router's pressed/released signals (guarded with is_connected).
func _disconnect_input_signals() -> void:
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_action_pressed.is_connected(_on_action_pressed):
			game.input_router.input_action_pressed.disconnect(_on_action_pressed)
		if game.input_router.input_action_released.is_connected(_on_action_released):
			game.input_router.input_action_released.disconnect(_on_action_released)
