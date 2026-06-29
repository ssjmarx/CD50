## cd_group_count_scaler.gd
## Produces: a scaled float based on current group count (empty→maximum, peak→minimum).
## Consumes: CDGame.group_registry for live entity counts; nothing on write.
class_name CDGroupCountScaler extends CDScaler

enum EasingType {
	LINEAR,
	EASE_IN,
	EASE_OUT
}

## group to count entities from
@export var group_name: StringName = &""

## easing function for the interpolation curve
@export var easing: EasingType = EasingType.LINEAR

## peak group size tracked across the wave (resets on group→empty→repopulate)
var _peak_count: int = 0

## was the group empty last frame? (detects wave transitions)
var _was_empty: bool = true

## Initialize — no signal connections needed, queries registry directly.
func initialize(game: CDGame) -> void:
	super.initialize(game)

## Return the scaled value based on current group count.
func evaluate() -> float:
	if _game == null or group_name == &"":
		return minimum

	var count: int = _game.group_registry.get_group(group_name).size()

	## detect wave transition: group went from empty to populated
	if count > 0 and _was_empty:
		_peak_count = 0
	_was_empty = (count == 0)

	## track peak dynamically (raises expected maximum if exceeded)
	_peak_count = maxi(_peak_count, count)

	## if no entities exist or peak is 0, return maximum value
	if _peak_count == 0 or count == 0:
		return maximum

	## calculate ratio of eliminated entities (0.0 = full group, 1.0 = empty group)
	var ratio := 1.0 - (float(count) / float(_peak_count))

	## apply easing curve
	var eased_ratio := ratio
	match easing:
		EasingType.LINEAR:
			pass
		EasingType.EASE_IN:
			## high curve value (>1) creates strong acceleration at the end
			eased_ratio = ease(ratio, 4.0)
		EasingType.EASE_OUT:
			## low curve value (<1) creates strong deceleration at the end
			eased_ratio = ease(ratio, 0.25)

	## interpolate smoothly between minimum and maximum based on the eased ratio
	return lerpf(minimum, maximum, eased_ratio)

## Reset peak tracking for game restart.
func reset() -> void:
	_peak_count = 0
	_was_empty = true