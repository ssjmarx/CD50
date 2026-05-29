# CDGroupCountTrigger
# Evaluative trigger — compares group entity count against a threshold
# Fires on rising edge only (false→true transition)

class_name CDGroupCountTrigger extends CDTrigger

# group to monitor via the group registry
@export var group_name: StringName = &""

# comparison operator for count vs threshold
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.LESS_OR_EQUAL

# value to compare the group count against
@export var threshold: int = 0

# tracks previous condition state for edge detection
var _was_met: bool = false

# mark as evaluative so composite triggers handle it correctly
func _init() -> void:
	is_evaluative = true

# fire on rising edge only (false→true), ignore sustained true
func evaluate(_delta: float) -> bool:
	var currently_met = _check_condition()
	if currently_met and not _was_met:
		_was_met = true
		return true
	_was_met = currently_met
	return false

# return current condition state (used by composite triggers)
func is_condition_met() -> bool:
	return _check_condition()

# clear edge detection state
func reset() -> void:
	_was_met = false
	super.reset()

# compare group count against threshold using the configured operator
func _check_condition() -> bool:
	if _game == null or group_name == &"":
		return false
	var count: int = _game.group_registry.get_count(group_name)
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