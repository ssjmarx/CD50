## CDGroupCountScaler
## Scales a float value based on the current count of entities in a group
## Returns MIN when the group is at peak capacity, MAX when the group is empty.
## The peak capacity dynamically adjusts upward if the group size ever exceeds it.

class_name CDGroupCountScaler extends CDScaler

## --- exports ---

## group to count entities from
@export var group_name: StringName = &""

## --- state ---

## peak group size tracked across the wave (resets on group→empty→repopulate)
var _peak_count: int = 0

## was the group empty last frame? (detects wave transitions)
var _was_empty: bool = true

## --- lifecycle ---

## initialize — no signal connections needed, queries registry directly
func initialize(game: CDGame) -> void:
	super.initialize(game)

## --- evaluation ---

## return the scaled value based on current group count
func evaluate() -> float:
	if _game == null or group_name == &"":
		return minimum

	var count: int = _game.group_registry.get_group(group_name).size()

	# detect wave transition: group went from empty to populated
	if count > 0 and _was_empty:
		_peak_count = 0
	_was_empty = (count == 0)

	# track peak dynamically (raises expected maximum if exceeded)
	_peak_count = maxi(_peak_count, count)

	# If no entities exist or peak is 0, return maximum value
	if _peak_count == 0 or count == 0:
		return maximum

	# Calculate ratio of eliminated entities (0.0 = full group, 1.0 = empty group)
	var ratio := 1.0 - (float(count) / float(_peak_count))

	# Interpolate smoothly between minimum and maximum based on the ratio
	return lerpf(minimum, maximum, ratio)

## --- reset ---

## reset peak tracking for game restart
func reset() -> void:
	_peak_count = 0
	_was_empty = true
