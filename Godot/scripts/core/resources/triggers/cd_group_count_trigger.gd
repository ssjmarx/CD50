## checks group population against a threshold.
class_name CDGroupCountTrigger extends CDTrigger

@export var group_name: StringName = &""
@export var comparison: CDEnums.CountComparison = CDEnums.CountComparison.LESS_OR_EQUAL
@export var threshold: int = 0

var _was_met: bool = false

func _init() -> void:
	is_evaluative = true

func evaluate(_delta: float) -> bool:
	var currently_met = _check_condition()
	# edge detection: fire on false→true transition only
	if currently_met and not _was_met:
		_was_met = true
		return true
	_was_met = currently_met
	return false

func is_condition_met() -> bool:
	return _check_condition()

func reset() -> void:
	_was_met = false
	super.reset()

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
