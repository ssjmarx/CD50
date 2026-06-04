## TimerCard
## Tracks time in countdown or count-up mode with configurable tick interval
## Auto-stops on expiry in COUNT_DOWN mode, supports pause/resume/reset

class_name TimerCard extends CDCueCard

## --- exports ---

enum TimerMode { COUNT_UP, COUNT_DOWN }

## direction of time tracking
@export var mode: TimerMode = TimerMode.COUNT_DOWN
## starting time in seconds
@export var starting_time: float = 60.0
## seconds between label updates and tick signals
@export var tick_interval: float = 1.0

@export_group("Blackboard Keys")
## key for publishing current time to game blackboard
@export var time_key: StringName = &"current_time"

## game bus signals for timer control
@export_group("Listen Signals")
@export var on_timer_pause: Array[StringName] = [&"timer_pause"]
@export var on_timer_resume: Array[StringName] = [&"timer_resume"]
@export var on_timer_reset: Array[StringName] = [&"timer_reset"]

## game bus signals emitted on tick and expiry
@export_group("Emit Signals")
@export var on_timer_tick: Array[StringName] = [&"timer_tick"]
@export var on_timer_expired: Array[StringName] = [&"timer_expired"]

## --- state ---

## current time value in seconds
var current_time: float
## accumulator for tick interval
var _tick_accumulator: float = 0.0
## whether the timer is actively running
var _is_running: bool = true

## --- lifecycle ---

## initialize time and display
func _ready() -> void:
	super._ready()
	current_time = starting_time
	_update_label(_format_time(current_time))
	call_deferred("_on_initialize")

## connect control signals to the game bus
func _on_initialize() -> void:
	_publish_tracked(time_key, current_time)
	for sig in on_timer_pause:
		game.bus_connect(sig, _on_timer_paused)
	for sig in on_timer_resume:
		game.bus_connect(sig, _on_timer_resumed)
	for sig in on_timer_reset:
		game.bus_connect(sig, _on_timer_reset)

## --- processing ---

## advance or decrement time each physics frame
func _physics_process(delta: float) -> void:
	if not _is_running:
		return

	match mode:
		TimerMode.COUNT_DOWN:
			current_time -= delta
			## check for expiry
			if current_time <= 0.0:
				current_time = 0.0
				_is_running = false
				_publish_tracked(time_key, current_time)
				_update_label(_format_time(0.0))
				for sig in on_timer_expired:
					game.bus_emit(sig)
				return
		TimerMode.COUNT_UP:
			current_time += delta

	## emit tick at configured interval
	_tick_accumulator += delta
	if _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		_publish_tracked(time_key, current_time)
		_update_label(_format_time(current_time))
		for sig in on_timer_tick:
			game.bus_emit(sig)

## --- control handlers ---

## pause the timer
func _on_timer_paused() -> void:
	_is_running = false

## resume the timer
func _on_timer_resumed() -> void:
	_is_running = true

## reset to starting time and resume
func _on_timer_reset() -> void:
	current_time = starting_time
	_tick_accumulator = 0.0
	_is_running = true
	_publish_tracked(time_key, current_time)
	_update_label(_format_time(current_time))

## --- formatting ---

## convert seconds to "M:SS" display string
func _format_time(time: float) -> String:
	@warning_ignore("integer_division")
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	return "%d:%02d" % [minutes, seconds]
