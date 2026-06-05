## CDGroupCountScaler
## Scales a float value based on the current count of entities in a group
## RATIO mode: base * (count / peak) — classic Space Invaders / Galaga speed ramp
## LINEAR mode: base + per_unit * count — additive scaling per entity

class_name CDGroupCountScaler extends CDScaler

enum Mode { RATIO, LINEAR }

## --- exports ---

## group to count entities from
@export var group_name: StringName = &""

## scaling mode — RATIO for proportional, LINEAR for additive
@export var mode: Mode = Mode.RATIO

## amount added per entity in LINEAR mode
@export var per_unit: float = 0.0

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
		return base

	var count: int = _game.group_registry.get_group(group_name).size()

	# detect wave transition: group went from empty to populated
	if count > 0 and _was_empty:
		_peak_count = 0
	_was_empty = (count == 0)

	# track peak
	_peak_count = maxi(_peak_count, count)

	var result: float
	match mode:
		Mode.RATIO:
			if _peak_count == 0 or count == 0:
				result = base
			else:
				result = base * (float(count) / float(_peak_count))
		Mode.LINEAR:
			result = base + per_unit * count

	return clampf(result, minimum, maximum)

## --- reset ---

## reset peak tracking for game restart
func reset() -> void:
	_peak_count = 0
	_was_empty = true