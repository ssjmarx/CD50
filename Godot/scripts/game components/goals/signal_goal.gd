## SignalGoal
## Ends the game or triggers a state change in direct response to game bus signals.
## Use case: Invaders reach the bottom of the screen -> Mark emits "end_game" -> Goal writes DEFEAT and emits "game_over"

class_name SignalGoal extends CDGameComponent

## --- exports ---

@export_group("Listen Signals")
## game bus signals that will trigger this goal
@export var trigger_signals: Array[StringName] = []

@export_group("Game Result")
## the result enum written to the blackboard when condition is met
@export var game_result: CDEnums.GameResult = CDEnums.GameResult.DEFEAT
## key to write the game_result under on the blackboard
@export var result_key: StringName = &"game_result"

@export_group("Emit Signals")
## game bus signals emitted on condition match
@export var on_condition_met: Array[StringName] = [&"game_over"]

## --- lifecycle ---

## connect to all configured trigger signals on the game bus (tracked for auto-disconnect)
func _on_initialize() -> void:
	connect_all(trigger_signals, _on_signal_received)

## --- signal handlers ---

## evaluate and fire the goal when a trigger signal is received
func _on_signal_received() -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return
	
	game.blackboard[result_key] = game_result
	
	for sig in on_condition_met:
		game.bus_emit(sig)
