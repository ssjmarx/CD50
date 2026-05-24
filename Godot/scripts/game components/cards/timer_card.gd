## tracks time and emits signals
class_name TimerCard extends CDCueCard

enum TimerMode { COUNT_UP, COUNT_DOWN }

@export var mode: TimerMode = TimerMode.COUNT_DOWN
@export var starting_time: float = 60.0
@export var tick_interval: float = 1.0

@export_group("Listen Signals")
@export var on_timer_pause: Array[StringName] = [&"timer_pause"]
@export var on_timer_resume: Array[StringName] = [&"timer_resume"]
@export var on_timer_reset: Array[StringName] = [&"timer_reset"]

@export_group("Emit Signals")
@export var on_timer_tick: Array[StringName] = [&"timer_tick"]
@export var on_timer_expired: Array[StringName] = [&"timer_expired"]

var current_time: float
var _tick_accumulator: float = 0.0
var _is_running: bool = true

func _ready() -> void:
	super._ready()
	current_time = starting_time
	_update_label(_format_time(current_time))
	call_deferred("_on_initialize")

func _on_initialize() -> void:
	for sig in on_timer_pause:
		game.bus_connect(sig, _on_timer_paused)
	for sig in on_timer_resume:
		game.bus_connect(sig, _on_timer_resumed)
	for sig in on_timer_reset:
		game.bus_connect(sig, _on_timer_reset)

func _physics_process(delta: float) -> void:
	if not _is_running:
		return
	
	match mode:
		TimerMode.COUNT_DOWN:
			current_time -= delta
			if current_time <= 0.0:
				current_time = 0.0
				_update_label(_format_time(0.0))
				for sig in on_timer_expired:
					game.bus_emit(sig)
				_is_running = false
				return
		TimerMode.COUNT_UP:
			current_time += delta
	
	_tick_accumulator += delta
	if _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		_update_label(_format_time(current_time))
		for sig in on_timer_tick:
			game.bus_emit(sig, [current_time])

func _on_timer_paused() -> void:
	_is_running = false

func _on_timer_resumed() -> void:
	_is_running = true

func _on_timer_reset() -> void:
	current_time = starting_time
	_tick_accumulator = 0.0
	_is_running = true
	_update_label(_format_time(current_time))

func _format_time(time: float) -> String:
	@warning_ignore("integer_division")
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	return "%d:%02d" % [minutes, seconds]
