# Game timer with count-up or count-down modes. Emits tick events at configurable intervals.

extends UniversalComponent

@export var duration: float = 60.0
@export var count_up: bool = false
@export var tick_interval: float = 1.0
@export var loop_timer: bool = false
@export var game_start: bool = false
@export var timer_id: String = ""
@export var emit_result_on_expire: bool = false  # Set true to emit result on expiry
@export var result: CommonEnums.Result  # Which result to emit (VICTORY or DEFEAT)

var _timer: Timer
var _current_time: float
var _is_running: bool = false

# Create and configure internal timer
func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_interval
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	
	if game_start:
		game.on_game_start.connect(func(): start_timer())

# Start the timer (counts up or down based on count_up mode)
func start_timer() -> void:
	if count_up:
		_current_time = 0.0
	else:
		_current_time = duration
	
	_is_running = true
	_timer.start()
	parent.timer_tick.emit(_current_time)

# Stop the timer without resetting
func stop_timer() -> void:
	_is_running = false
	_timer.stop()

# Stop timer and reset to starting value
func reset_timer() -> void:
	stop_timer()
	if count_up:
		_current_time = 0.0
	else:
		_current_time = duration

# Handle timer tick at tick_interval
func _on_tick() -> void:
	if not _is_running:
		return
	
	if count_up:
		_current_time += tick_interval
		if _current_time >= duration:
			_current_time = duration
			stop_timer()
			game.timer_expired.emit(timer_id)
			_emit_result()
			if loop_timer:
				reset_timer()
				start_timer()
	else:
		_current_time -= tick_interval
		if _current_time <= 0:
			_current_time = 0
			stop_timer()
			game.timer_expired.emit(timer_id)
			_emit_result()
			if loop_timer:
				reset_timer()
				start_timer()
	
	game.timer_tick.emit(_current_time)

# Emit victory or defeat on expiry based on configured result
func _emit_result() -> void:
	if not emit_result_on_expire:
		return
	match result:
		CommonEnums.Result.VICTORY: parent.victory.emit()
		CommonEnums.Result.DEFEAT: parent.defeat.emit()
