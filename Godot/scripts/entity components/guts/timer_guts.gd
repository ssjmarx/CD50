## emits tick and expired signals on a timer
class_name TimerGuts extends CDEntityComponent

enum TimerMode { COUNT_DOWN, COUNT_UP }

@export var mode: TimerMode = TimerMode.COUNT_DOWN
@export var starting_time: float = 60.0
@export var tick_interval: float = 1.0
@export var auto_start: bool = true

@export_group("Listen Signals")
@export var pause_signals: Array[StringName] = [&"timer_pause"]
@export var resume_signals: Array[StringName] = [&"timer_resume"]
@export var reset_signals: Array[StringName] = [&"timer_reset"]

@export_group("Emit Signals")
@export var tick_signals: Array[StringName] = [&"timer_tick"]
@export var expired_signals: Array[StringName] = [&"timer_expired"]

var current_time: float
var _tick_accumulator: float = 0.0
var _is_running: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in pause_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_paused)
	for sig in resume_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_resumed)
	for sig in reset_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_reset)
	for sig in tick_signals:
		entity.ensure_signal(sig)
	for sig in expired_signals:
		entity.ensure_signal(sig)
	
	current_time = starting_time
	_is_running = auto_start

func _physics_process(delta: float) -> void:
	if not _is_running:
		return
	
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
	
	_tick_accumulator += delta
	if _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		for sig in tick_signals:
			entity.emit_signal(sig)

func _on_paused() -> void:
	_is_running = false

func _on_resumed() -> void:
	_is_running = true

func _on_reset() -> void:
	current_time = starting_time
	_tick_accumulator = 0.0
	_is_running = true

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
