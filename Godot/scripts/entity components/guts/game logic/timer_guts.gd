## TimerGuts
## Count-down or count-up timer that emits tick and expired signals
## Writes current time to entity blackboard; emits zero-arg signals on events Supports pause, resume, and reset via entity signals

class_name TimerGuts extends CDEntityComponent

## --- enums ---

enum TimerMode { COUNT_DOWN, COUNT_UP }

## --- exports ---

@export var mode: TimerMode = TimerMode.COUNT_DOWN
@export var starting_time: float = 60.0
@export var tick_interval: float = 1.0
@export var auto_start: bool = true

@export_group("Blackboard Keys")
@export var value_key: StringName = &"timer_time"

@export_group("Listen Signals")
@export var pause_signals: Array[StringName] = [&"timer_pause"]
@export var resume_signals: Array[StringName] = [&"timer_resume"]
@export var reset_signals: Array[StringName] = [&"timer_reset"]

@export_group("Emit Signals")
@export var tick_signals: Array[StringName] = [&"timer_tick"]
@export var expired_signals: Array[StringName] = [&"timer_expired"]

## --- state ---

var current_time: float
var _tick_accumulator: float = 0.0
var _is_running: bool = false

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in pause_signals:
		entity.bus_connect(sig, _on_paused)
	for sig in resume_signals:
		entity.bus_connect(sig, _on_resumed)
	for sig in reset_signals:
		entity.bus_connect(sig, _on_reset)
	
	current_time = starting_time
	entity.blackboard[value_key] = current_time
	_is_running = auto_start

## --- processing ---

## physics process
func _physics_process(delta: float) -> void:
	if not _is_running:
		return
	
	match mode:
		TimerMode.COUNT_DOWN:
			current_time -= delta
			if current_time <= 0.0:
				current_time = 0.0
				_is_running = false
				entity.blackboard[value_key] = 0.0
				for sig in expired_signals:
					entity.bus_emit(sig)
				return
		TimerMode.COUNT_UP:
			current_time += delta
	
	entity.blackboard[value_key] = current_time
	
	_tick_accumulator += delta
	if _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		for sig in tick_signals:
			entity.bus_emit(sig)

## --- control signal handlers ---

## on paused
func _on_paused() -> void:
	_is_running = false

## on resumed
func _on_resumed() -> void:
	_is_running = true

## on reset
func _on_reset() -> void:
	current_time = starting_time
	_tick_accumulator = 0.0
	_is_running = true
	entity.blackboard[value_key] = current_time

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_running = false
	entity.blackboard.erase(value_key)
	for sig in pause_signals:
		entity.bus_disconnect(sig, _on_paused)
	for sig in resume_signals:
		entity.bus_disconnect(sig, _on_resumed)
	for sig in reset_signals:
		entity.bus_disconnect(sig, _on_reset)