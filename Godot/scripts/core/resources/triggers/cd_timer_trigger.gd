## CDTimerTrigger
## Event trigger — fires on a configurable timer interval
## Optional random variance adds ±jitter to each interval

class_name CDTimerTrigger extends CDTrigger

## base time between fires (seconds)
@export var interval: float = 5.0

## optional scaler — overrides interval when assigned
@export var scaler: CDScaler

## ±random offset added to interval each cycle
@export var random_variance: float = 0.0

## countdown until next fire
var _time_until_fire: float = 0.0

## set initial timer on initialization
func initialize(game: CDGame) -> void:
	super.initialize(game)
	if scaler:
		scaler.initialize(game)
	_reset_timer()

## count down and fire when time expires
func evaluate(delta: float) -> bool:
	_time_until_fire -= delta
	if _time_until_fire <= 0.0:
		_reset_timer()
		return true
	return false

## clear timer state on reset
func reset() -> void:
	super.reset()
	_time_until_fire = 0.0
	if scaler:
		scaler.reset()

## reset timer to interval ± random variance
func _reset_timer() -> void:
	var effective_interval := interval
	if scaler:
		effective_interval = scaler.evaluate()
	_time_until_fire = effective_interval
	if random_variance > 0.0:
		_time_until_fire += randf_range(-random_variance, random_variance)
	# print("[TIMER_RESET] %.2fs | base=%.2f effective=%.2f variance=%.2f → countdown=%.2f" % [
	# 	Time.get_ticks_msec() / 1000.0, interval, effective_interval, random_variance, _time_until_fire])
