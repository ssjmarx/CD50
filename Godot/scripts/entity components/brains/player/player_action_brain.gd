## PlayerActionBrain
## Converts player inputs into named signals
## Only listens for configured actions

class_name PlayerActionBrain extends CDEntityComponent

@export var player_id: int = 1
@export var action_mappings: Array[StringName] = [&"fire"]

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## on initialize
func _on_initialize() -> void:
	_connect_input_signals()

## on action pressed
func _on_action_pressed(pid: int, action: StringName) -> void:
	if pid != player_id or action not in action_mappings:
		return
	entity.bus_emit(action)

## on action released
func _on_action_released(pid: int, action: StringName) -> void:
	if pid != player_id or action not in action_mappings:
		return
	entity.bus_emit(StringName(action + &"_end"))

## on sleep                                                               
func _on_sleep() -> void:                                                 
	super._on_sleep()                                                     
	_disconnect_input_signals()
																		  
## on wake                                                                
func _on_wake() -> void:                                                  
	super._on_wake()                                                      
	_connect_input_signals()

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_disconnect_input_signals()

## --- Helpers ---

func _connect_input_signals() -> void:
	if is_instance_valid(game) and game.input_router:
		if not game.input_router.input_action_pressed.is_connected(_on_action_pressed):
			game.input_router.input_action_pressed.connect(_on_action_pressed)
		if not game.input_router.input_action_released.is_connected(_on_action_released):
			game.input_router.input_action_released.connect(_on_action_released)

func _disconnect_input_signals() -> void:
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_action_pressed.is_connected(_on_action_pressed):
			game.input_router.input_action_pressed.disconnect(_on_action_pressed)
		if game.input_router.input_action_released.is_connected(_on_action_released):
			game.input_router.input_action_released.disconnect(_on_action_released)
