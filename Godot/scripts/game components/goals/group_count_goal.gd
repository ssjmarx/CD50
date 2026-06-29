## GroupCountGoal
## Produces: a goal_met game bus signal when group counts match a comparison.
## Consumes: target group entity counts; CDTrigger resources.

class_name GroupCountGoal extends CDGameComponent

## --- lifecycle ---

## set component category (consistent with the rest of the codebase)
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

## --- exports ---

## groups whose entity counts are monitored
@export var target_groups: Array[StringName] = [&"enemies"]
## comparison operator applied to each group's count
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.EQUAL_TO
## the count value to compare against
@export var target_count: int = 0
## true = ALL groups must match, false = ANY group must match
@export var require_all_groups: bool = true

@export_group("Blackboard Keys")
## key pattern for writing group counts to game blackboard (group_name appended at runtime)
## e.g. "enemies_count" for group &"enemies"
@export var count_key_suffix: StringName = &"_count"

@export_group("Game Result")
## the result enum written to the blackboard when condition is met
@export var game_result: CDEnums.GameResult = CDEnums.GameResult.VICTORY
## key to write the game_result under on the blackboard
@export var result_key: StringName = &"game_result"

## game bus signals emitted on condition match and count change
## add "game_over" to this array in the inspector to trigger the end of the game
@export_group("Emit Signals")
## informational signals — emitted on success but do not end the game
@export var on_condition_met: Array[StringName] = [&"goal_reached"]
## terminator signals — emitted on success to end the game (e.g. game_over)
@export var end_game_signals: Array[StringName] = []
@export var on_count_changed: Array[StringName] = [&"enemies_count_changed"]

## listen to group registry count changes
func _on_initialize() -> void:
	game.group_registry.group_count_changed.connect(_on_group_count_changed)

## --- signal handlers ---

## check condition whenever a watched group's count changes
func _on_group_count_changed(group_name: StringName, count: int) -> void:
	if group_name not in target_groups:
		return
	if game.current_state == CDEnums.GameState.GAME_OVER:       
		return
	
	game.blackboard[StringName(group_name + String(count_key_suffix))] = count
	
	for sig in on_count_changed:
		game.bus_emit(sig)
	
	if _check_condition():
		game.blackboard[result_key] = game_result
		for sig in on_condition_met:
			game.bus_emit(sig)
		for sig in end_game_signals:
			game.bus_emit(sig)

## --- condition checking ---

## test all target groups against the comparison (AND or OR logic)
func _check_condition() -> bool:
	if require_all_groups:
		## AND: every group must satisfy the comparison
		for g in target_groups:
			if not _compare(game.group_registry.get_count(g)):
				return false
		return true
	else:
		## OR: at least one group must satisfy the comparison
		for g in target_groups:
			if _compare(game.group_registry.get_count(g)):
				return true
		return false

## compare an observed count against target_count using the shared CDEnums helper
func _compare(observed: int) -> bool:
	return CDEnums.compare(observed, target_count, comparison)
