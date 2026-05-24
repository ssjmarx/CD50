## triggers when score crosses a threshold
class_name ScoreThresholdGoal extends CDGameComponent

@export var threshold: int = 10000
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.GREATER_OR_EQUAL

@export_group("Listen Signals")
@export var on_score_changed: Array[StringName] = [&"score_changed"]

@export_group("Emit Signals")
@export var on_condition_met: Array[StringName] = [&"game_end_victory"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

func _on_initialize() -> void:
	for sig in on_score_changed:
		game.bus_connect(sig, _on_score_updated)

func _on_score_updated(new_score: int) -> void:
	if _compare(new_score):
		for sig in on_condition_met:
			game.bus_emit(sig)

func _compare(observed: int) -> bool:
	match comparison:
		CDEnums.CountComparison.LESS_THAN: return observed < threshold
		CDEnums.CountComparison.EQUAL_TO: return observed == threshold
		CDEnums.CountComparison.GREATER_THAN: return observed > threshold
		CDEnums.CountComparison.LESS_OR_EQUAL: return observed <= threshold
		CDEnums.CountComparison.GREATER_OR_EQUAL: return observed >= threshold
	return false
