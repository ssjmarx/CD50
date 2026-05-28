## fires on a configurable timer interval.
class_name CDTimerTrigger extends CDTrigger

@export var interval: float = 5.0
@export var random_variance: float = 0.0

var _time_until_fire: float = 0.0

func initialize(game: CDGame) -> void:
	super.initialize(game)
	_reset_timer()

func evaluate(delta: float) -> bool:
	_time_until_fire -= delta
	if _time_until_fire <= 0.0:
		_reset_timer()
		return true
	return false

func reset() -> void:
	super.reset()
	_time_until_fire = 0.0

func _reset_timer() -> void:
	_time_until_fire = interval
	if random_variance > 0.0:
		_time_until_fire += randf_range(-random_variance, random_variance)
