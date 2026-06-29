## ScoreThresholdGoal
## Produces: a goal_met game bus signal when score crosses a threshold.
## Consumes: game.blackboard score key; CDTrigger resources.

class_name ScoreThresholdGoal extends CDGameComponent

## --- exports ---

## the score value to compare against
@export var threshold: int = 10000
## comparison operator applied to the observed score
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.GREATER_OR_EQUAL

@export_group("Blackboard Keys")
## key to read current score from game blackboard (int)
@export var score_key: StringName = &"current_score"

@export_group("Game Result")
## the result enum written to the blackboard when condition is met
@export var game_result: CDEnums.GameResult = CDEnums.GameResult.VICTORY
## key to write the game_result under on the blackboard
@export var result_key: StringName = &"game_result"

## game bus signals that indicate score has changed (zero-arg)
@export_group("Listen Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]

## game bus signals emitted when the threshold is crossed
## add "game_over" to this array in the inspector to trigger the end of the game
@export_group("Emit Signals")
## informational signals — emitted on success but do not end the game
@export var on_condition_met: Array[StringName] = [&"goal_reached"]
## terminator signals — emitted on success to end the game (e.g. game_over)
@export var end_game_signals: Array[StringName] = []

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

## connect score change signals to the game bus
func _on_initialize() -> void:
	for sig in on_score_changed:
		bus_connect(sig, _on_score_updated)

## --- signal handlers ---

## read score from blackboard and check condition (zero-arg)
func _on_score_updated() -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:       
		return
	
	var score: int = game.blackboard.get(score_key, 0)
	if _compare(score):
		game.blackboard[result_key] = game_result
		for sig in on_condition_met:
			game.bus_emit(sig)
		for sig in end_game_signals:
			game.bus_emit(sig)

## --- condition checking ---

## compare an observed score against threshold using the shared CDEnums helper
func _compare(observed: int) -> bool:
	return CDEnums.compare(observed, threshold, comparison)
