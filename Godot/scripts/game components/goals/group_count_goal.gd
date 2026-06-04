## GroupCountGoal
## Monitors group sizes and triggers when entity counts match a comparison
## Supports AND (all groups) or OR (any group) logic across multiple target groups

class_name GroupCountGoal extends CDGameComponent

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

## game bus signals emitted on condition match and count change
@export_group("Emit Signals")
@export var on_condition_met: Array[StringName] = [&"game_end_victory"]
@export var on_count_changed: Array[StringName] = [&"enemies_count_changed"]

## --- lifecycle ---

## listen to group registry count changes
func _on_initialize() -> void:
	game.group_registry.group_count_changed.connect(_on_group_count_changed)

## --- signal handlers ---

## check condition whenever a watched group's count changes
func _on_group_count_changed(group_name: StringName, count: int) -> void:
	if group_name not in target_groups:
		return
	
	game.blackboard[StringName(group_name + String(count_key_suffix))] = count
	
	for sig in on_count_changed:
		game.bus_emit(sig)
	
	if _check_condition():
		for sig in on_condition_met:
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

## compare an observed count against target_count using the configured operator
func _compare(observed: int) -> bool:
	match comparison:
		CDEnums.CountComparison.LESS_THAN: return observed < target_count
		CDEnums.CountComparison.EQUAL_TO: return observed == target_count
		CDEnums.CountComparison.GREATER_THAN: return observed > target_count
		CDEnums.CountComparison.LESS_OR_EQUAL: return observed <= target_count
		CDEnums.CountComparison.GREATER_OR_EQUAL: return observed >= target_count
	return false