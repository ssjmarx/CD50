# Game timer with count-up or count-down modes. Emits tick events at configurable intervals.

extends Node

@export var duration: float = 60.0 # Timer duration in seconds
@export var count_up: bool = false # If true, counts up from 0 to duration. If false, counts down from duration to 0
@export var tick_interval: float = 1.0 # Time between timer_tick emissions

var _timer: Timer # Internal timer node
var _current_time: float # Current timer value
var _is_running: bool = false # Timer running state

@onready var parent = get_parent() # Reference to game script

# Create and configure internal timer
func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = tick_interval
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

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
	
	# Update time based on count_up mode
	if count_up:
		_current_time += tick_interval
		if _current_time >= duration:
			_current_time = duration
			stop_timer()
			parent.timer_expired.emit()
	else:
		_current_time -= tick_interval
		if _current_time <= 0:
			_current_time = 0
			stop_timer()
			parent.timer_expired.emit()
	
	# Emit tick event with current time
	parent.timer_tick.emit(_current_time)