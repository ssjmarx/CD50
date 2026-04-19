# Game timer with count-up or count-down modes. Emits tick events at configurable intervals.

extends UniversalComponent

@export var duration: float = 60.0
@export var count_up: bool = false
@export var tick_interval: float = 1.0
@export var loop_timer: bool = false
@export var game_start: bool = false
@export var timer_id: String = ""

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
	#print("timer started")
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
	#print("tick")
	if not _is_running:
		return
	
	if count_up:
		_current_time += tick_interval
		if _current_time >= duration:
			_current_time = duration
			stop_timer()
			game.timer_expired.emit(timer_id)
			if loop_timer:
				#print("looping")
				reset_timer()
				start_timer()
	else:
		_current_time -= tick_interval
		if _current_time <= 0:
			_current_time = 0
			stop_timer()
			game.timer_expired.emit(timer_id)
			if loop_timer:
				reset_timer()
				start_timer()
	
	game.timer_tick.emit(_current_time)
