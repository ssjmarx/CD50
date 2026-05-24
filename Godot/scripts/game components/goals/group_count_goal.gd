## triggers when group counts match a condition
class_name GroupCountGoal extends CDGameComponent

@export var target_groups: Array[StringName] = [&"enemies"]
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.EQUAL_TO
@export var target_count: int = 0
@export var require_all_groups: bool = true

@export_group("Emit Signals")
@export var on_condition_met: Array[StringName] = [&"game_end_victory"]
@export var on_count_changed: Array[StringName] = [&"enemies_count_changed"]

func _on_initialize() -> void:
	game.group_registry.group_count_changed.connect(_on_group_count_changed)

func _on_group_count_changed(group_name: StringName, count: int) -> void:
	if group_name not in target_groups:
		return
	
	for sig in on_count_changed:
		game.bus_emit(sig, [count])
	
	if _check_condition():
		for sig in on_condition_met:
			game.bus_emit(sig)

func _check_condition() -> bool:
	if require_all_groups:
		for g in target_groups:
			if not _compare(game.group_registry.get_count(g)):
				return false
		return true
	else:
		for g in target_groups:
			if _compare(game.group_registry.get_count(g)):
				return true
		return false

func _compare(observed: int) -> bool:
	match comparison:
		CDEnums.CountComparison.LESS_THAN: return observed < target_count
		CDEnums.CountComparison.EQUAL_TO: return observed == target_count
		CDEnums.CountComparison.GREATER_THAN: return observed > target_count
		CDEnums.CountComparison.LESS_OR_EQUAL: return observed <= target_count
		CDEnums.CountComparison.GREATER_OR_EQUAL: return observed >= target_count
	return false
