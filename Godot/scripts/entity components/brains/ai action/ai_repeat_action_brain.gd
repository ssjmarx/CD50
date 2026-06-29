## ai_repeat_action_brain.gd
## Produces: a repeated fire-action entity-bus signal at a wave-scaled interval while active.
## Consumes: start/stop entity-bus signals; fire_interval/wave_scaler config.
class_name AIRepeatActionBrain extends CDEntityComponent

@export var fire_interval: float = 0.3
@export var wave_scaler: CDWaveScaler

@export_group("Listen Signals")
@export var start_signals: Array[StringName] = [&"start_shooting"]
@export var stop_signals: Array[StringName] = [&"stop_shooting"]

@export_group("Emit Signals")
@export var fire_action: StringName = &"shoot"

var _timer: float = 0.0
var _is_active: bool = false

## Initialize the wave scaler and connect each start/stop signal during setup.
func _on_initialize() -> void:
	if wave_scaler:
		wave_scaler.initialize(entity.game)
	for sig in start_signals:
		self.bus_connect(sig, _on_start)
	for sig in stop_signals:
		self.bus_connect(sig, _on_stop)

## Advance the fire timer and emit the action signal each interval while active.
func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	var effective_interval := fire_interval
	if wave_scaler:
		effective_interval = wave_scaler.evaluate()
	_timer += delta
	if _timer >= effective_interval:
		_timer = 0.0
		entity.bus_emit(fire_action)

## Activate repeating fire and prime the timer for the first shot.
func _on_start() -> void:
	if _is_active: return
	_is_active = true
	_timer = fire_interval

## Deactivate repeating fire and emit the end suffix signal.
func _on_stop() -> void:
	if not _is_active: return
	_is_active = false
	_timer = 0.0
	entity.bus_emit(StringName(fire_action + &"_end"))

## Stop firing, then disconnect all start/stop signals on entity deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_active: _on_stop()
	for sig in start_signals:
		self.bus_disconnect(sig, _on_start)
	for sig in stop_signals:
		self.bus_disconnect(sig, _on_stop)
