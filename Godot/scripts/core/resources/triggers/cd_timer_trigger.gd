## cd_timer_trigger.gd
## Produces: a moment-based trigger that fires on a configurable timer interval (+jitter).
## Consumes: an optional CDScaler to override the interval.
class_name CDTimerTrigger extends CDTrigger

## base time between fires (seconds)
@export var interval: float = 5.0

## optional scaler — overrides interval when assigned
@export var scaler: CDScaler

## ±random offset added to interval each cycle
@export var random_variance: float = 0.0

## countdown until next fire
var _time_until_fire: float = 0.0

## Seed the timer (and scaler) on initialization.
func initialize(game: CDGame) -> void:
	super.initialize(game)
	if scaler:
		scaler.initialize(game)
	_reset_timer()

## Count down each frame and fire when the interval elapses.
func evaluate(delta: float) -> bool:
	_time_until_fire -= delta
	if _time_until_fire <= 0.0:
		_reset_timer()
		return true
	return false

## Clear timer (and scaler) state on reset.
func reset() -> void:
	super.reset()
	_time_until_fire = 0.0
	if scaler:
		scaler.reset()

## Reset the countdown to the effective interval ± random variance.
func _reset_timer() -> void:
	var effective_interval := interval
	if scaler:
		effective_interval = scaler.evaluate()
	_time_until_fire = effective_interval
	if random_variance > 0.0:
		_time_until_fire += randf_range(-random_variance, random_variance)