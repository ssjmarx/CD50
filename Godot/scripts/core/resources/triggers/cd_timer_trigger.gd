## CDTimerTrigger
## Event trigger — fires on a configurable timer interval
## Optional random variance adds ±jitter to each interval

class_name CDTimerTrigger extends CDTrigger

## base time between fires (seconds)
@export var interval: float = 5.0

## optional wave scaler — overrides interval when assigned
@export var wave_scaler: CDWaveScaler

## ±random offset added to interval each cycle
@export var random_variance: float = 0.0

## countdown until next fire
var _time_until_fire: float = 0.0

## set initial timer on initialization
func initialize(game: CDGame) -> void:
	super.initialize(game)
	if wave_scaler:
		wave_scaler.initialize(game)
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
	if wave_scaler:
		wave_scaler.reset()

## reset timer to interval ± random variance
func _reset_timer() -> void:
	var effective_interval := interval
	if wave_scaler:
		effective_interval = wave_scaler.evaluate()
	_time_until_fire = effective_interval
	if random_variance > 0.0:
		_time_until_fire += randf_range(-random_variance, random_variance)
