# ScoreThresholdGoal
# Monitors score via game bus and triggers when it crosses a threshold
# Uses CDEnums.CountComparison for flexible comparison operators

class_name ScoreThresholdGoal extends CDGameComponent

# --- exports ---

# the score value to compare against
@export var threshold: int = 10000
# comparison operator applied to the observed score
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.GREATER_OR_EQUAL

# game bus signals that provide score updates
@export_group("Listen Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]

# game bus signals emitted when the threshold is crossed
@export_group("Emit Signals")
@export var on_condition_met: Array[StringName] = [&"game_end_victory"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

# connect score change signals to the game bus
func _on_initialize() -> void:
	for sig in on_score_changed:
		game.bus_connect(sig, _on_score_updated)

# --- signal handlers ---

# check condition whenever score updates
func _on_score_updated(new_score: int) -> void:
	if _compare(new_score):
		for sig in on_condition_met:
			game.bus_emit(sig)

# --- condition checking ---

# compare an observed score against threshold using the configured operator
func _compare(observed: int) -> bool:
	match comparison:
		CDEnums.CountComparison.LESS_THAN: return observed < threshold
		CDEnums.CountComparison.EQUAL_TO: return observed == threshold
		CDEnums.CountComparison.GREATER_THAN: return observed > threshold
		CDEnums.CountComparison.LESS_OR_EQUAL: return observed <= threshold
		CDEnums.CountComparison.GREATER_OR_EQUAL: return observed >= threshold
	return false