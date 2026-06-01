# AIRepeatActionBrain
# Repeats an action signal at a given interval
# Responds to start/stop signals

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

func _on_initialize() -> void:
	if wave_scaler:
		wave_scaler.initialize(entity.game)
	for sig in start_signals:
		entity.bus_connect(sig, _on_start)
	for sig in stop_signals:
		entity.bus_connect(sig, _on_stop)

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

func _on_start() -> void:
	if _is_active: return
	_is_active = true
	_timer = fire_interval

func _on_stop() -> void:
	if not _is_active: return
	_is_active = false
	_timer = 0.0
	entity.bus_emit(StringName(fire_action + &"_end"))

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_active: _on_stop()
	for sig in start_signals:
		entity.bus_disconnect(sig, _on_start)
	for sig in stop_signals:
		entity.bus_disconnect(sig, _on_stop)
