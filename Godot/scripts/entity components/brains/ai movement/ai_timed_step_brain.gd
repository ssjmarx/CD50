# AITimedStepBrain
# Emits a directional signal at a regular interval
# Listens on the entity bus for speed multiplier changes, direction changes, and resets

class_name AITimedStepBrain extends CDEntityComponent

# base seconds between each step
@export var step_interval: float = 1.0

# default direction emitted each step
@export var step_direction: Vector2 = Vector2.DOWN

@export_group("Listen Signals")
@export var change_speed_signals: Array[StringName] = [&"speed_up"]
@export var change_direction_signals: Array[StringName] = [&"change_direction"]
@export var reset_signals: Array[StringName] = [&"reset_step"]

@export_group("Emit Signals")
@export var step_signals: Array[StringName] = [&"move"]

# time since last step emission
var _timer: float = 0.0

# current interval (can be modified by speed signals)
var _current_interval: float

# current direction (can be modified by direction signals)
var _current_direction: Vector2

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# initialize runtime values, ensure signals, and connect listeners
func _on_initialize() -> void:
	_current_interval = step_interval
	_current_direction = step_direction
	
	for sig in step_signals:
		entity.ensure_signal(sig)
	for sig in change_speed_signals:
		entity.ensure_signal(sig)
	for sig in change_direction_signals:
		entity.ensure_signal(sig)
	for sig in reset_signals:
		entity.ensure_signal(sig)
	
	for sig in change_speed_signals:
		entity.connect(sig, _on_change_speed)
	for sig in change_direction_signals:
		entity.connect(sig, _on_change_direction)
	for sig in reset_signals:
		entity.connect(sig, _on_reset)

# emit step direction when timer reaches the current interval
func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= _current_interval:
		_timer = 0.0
		for sig in step_signals:
			entity.emit_signal(sig, _current_direction)

# multiply the current interval (e.g., speed_up = 0.5 makes steps twice as fast)
func _on_change_speed(multiplier: float) -> void:
	_current_interval *= multiplier

# change the direction emitted each step
func _on_change_direction(new_direction: Vector2) -> void:
	_current_direction = new_direction

# restore original interval, direction, and reset timer
func _on_reset() -> void:
	_current_interval = step_interval
	_current_direction = step_direction
	_timer = 0.0

# reset all state and disconnect listen signals
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_timer = 0.0
	_current_interval = step_interval
	_current_direction = step_direction
	for sig in change_speed_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_change_speed):
			entity.disconnect(sig, _on_change_speed)
	for sig in change_direction_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_change_direction):
			entity.disconnect(sig, _on_change_direction)
	for sig in reset_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_reset):
			entity.disconnect(sig, _on_reset)
