## cd_group_count_trigger.gd
## Produces: an evaluative trigger comparing group counts to a threshold (fires on rising edge).
## Consumes: game.group_registry counts for the configured group_names.
class_name CDGroupCountTrigger extends CDTrigger

## groups to monitor via the group registry
@export var group_names: Array[StringName] = []

## comparison operator for count vs threshold
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.LESS_OR_EQUAL

## value to compare each group count against
@export var threshold: int = 0

## true = ALL groups must satisfy the condition; false = ANY group satisfies
@export var require_all: bool = true

## tracks previous condition state for edge detection
var _was_met: bool = false

## mark as evaluative so composite triggers handle it correctly
func _init() -> void:
	is_evaluative = true

## fire on rising edge only (false→true), ignore sustained true
func evaluate(_delta: float) -> bool:
	var currently_met = _check_condition()
	if currently_met and not _was_met:
		_was_met = true
		return true
	_was_met = currently_met
	return false

## return current condition state (used by composite triggers)
func is_condition_met() -> bool:
	return _check_condition()

## clear edge detection state
func reset() -> void:
	_was_met = false
	super.reset()

## check if groups satisfy the condition based on require_all mode
func _check_condition() -> bool:
	if _game == null or group_names.is_empty():
		return false
	
	if require_all:
		for group_name in group_names:
			if group_name == &"":
				return false
			if not _compare(_game.group_registry.get_count(group_name)):
				return false
		return true
	else:
		for group_name in group_names:
			if group_name == &"":
				continue
			if _compare(_game.group_registry.get_count(group_name)):
				return true
		return false

## compare a single count against threshold using the configured operator
func _compare(count: int) -> bool:
	match comparison:
		CDEnums.CountComparison.LESS_THAN:
			return count < threshold
		CDEnums.CountComparison.EQUAL_TO:
			return count == threshold
		CDEnums.CountComparison.GREATER_THAN:
			return count > threshold
		CDEnums.CountComparison.LESS_OR_EQUAL:
			return count <= threshold
		CDEnums.CountComparison.GREATER_OR_EQUAL:
			return count >= threshold
	return false