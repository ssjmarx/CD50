## emits a directional signal at a regular interval. listens on the entity bus 
## for speed multiplier changes, direction changes, and resets.
class_name AITimedStepBrain extends CDEntityComponent

@export var step_interval: float = 1.0
@export var step_direction: Vector2 = Vector2.DOWN

@export_group("Listen Signals")
@export var change_speed_signals: Array[StringName] = [&"speed_up"]
@export var change_direction_signals: Array[StringName] = [&"change_direction"]
@export var reset_signals: Array[StringName] = [&"reset_step"]

@export_group("Emit Signals")
@export var step_signals: Array[StringName] = [&"move"]

var _timer: float = 0.0
var _current_interval: float
var _current_direction: Vector2

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

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

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= _current_interval:
		_timer = 0.0
		for sig in step_signals:
			entity.emit_signal(sig, _current_direction)

func _on_change_speed(multiplier: float) -> void:
	_current_interval *= multiplier

func _on_change_direction(new_direction: Vector2) -> void:
	_current_direction = new_direction

func _on_reset() -> void:
	_current_interval = step_interval
	_current_direction = step_direction
	_timer = 0.0

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
