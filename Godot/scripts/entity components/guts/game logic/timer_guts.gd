# TimerGuts
# Count-down or count-up timer that emits tick and expired signals
# Supports pause, resume, and reset via entity signals

class_name TimerGuts extends CDEntityComponent

# --- enums ---

enum TimerMode { COUNT_DOWN, COUNT_UP }

# --- exports ---

# whether the timer counts down or up
@export var mode: TimerMode = TimerMode.COUNT_DOWN
# starting time value in seconds
@export var starting_time: float = 60.0
# seconds between tick emissions
@export var tick_interval: float = 1.0
# whether the timer starts automatically on initialize
@export var auto_start: bool = true

# signals that pause the timer
@export_group("Listen Signals")
@export var pause_signals: Array[StringName] = [&"timer_pause"]
# signals that resume the timer
@export var resume_signals: Array[StringName] = [&"timer_resume"]
# signals that reset the timer to starting_time and resume
@export var reset_signals: Array[StringName] = [&"timer_reset"]

# emitted at each tick interval (float current_time)
@export_group("Emit Signals")
@export var tick_signals: Array[StringName] = [&"timer_tick"]
# emitted when count-down reaches zero
@export var expired_signals: Array[StringName] = [&"timer_expired"]

# --- state ---

# current time value (public for external reads)
var current_time: float
# accumulator for tick interval
var _tick_accumulator: float = 0.0
# whether the timer is currently running
var _is_running: bool = false

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect control signals and set initial time
func _on_initialize() -> void:
	# connect pause, resume, and reset listeners
	for sig in pause_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_paused)
	for sig in resume_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_resumed)
	for sig in reset_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_reset)
	
	# ensure emit signals exist
	for sig in tick_signals:
		entity.ensure_signal(sig)
	for sig in expired_signals:
		entity.ensure_signal(sig)
	
	current_time = starting_time
	_is_running = auto_start

# --- processing ---

# tick the timer based on mode, emit tick and expired signals
func _physics_process(delta: float) -> void:
	if not _is_running:
		return
	
	# update time based on mode
	match mode:
		TimerMode.COUNT_DOWN:
			current_time -= delta
			if current_time <= 0.0:
				current_time = 0.0
				_is_running = false
				for sig in expired_signals:
					entity.emit_signal(sig)
				return
		TimerMode.COUNT_UP:
			current_time += delta
	
	# emit tick at regular intervals
	_tick_accumulator += delta
	if _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		for sig in tick_signals:
			entity.emit_signal(sig)

# --- control signal handlers ---

# stop the timer
func _on_paused() -> void:
	_is_running = false

# resume the timer
func _on_resumed() -> void:
	_is_running = true

# reset to starting time and resume
func _on_reset() -> void:
	current_time = starting_time
	_tick_accumulator = 0.0
	_is_running = true

# --- cleanup ---

# stop and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_running = false
	for sig in pause_signals:
		if entity.is_connected(sig, _on_paused):
			entity.disconnect(sig, _on_paused)
	for sig in resume_signals:
		if entity.is_connected(sig, _on_resumed):
			entity.disconnect(sig, _on_resumed)
	for sig in reset_signals:
		if entity.is_connected(sig, _on_reset):
			entity.disconnect(sig, _on_reset)
