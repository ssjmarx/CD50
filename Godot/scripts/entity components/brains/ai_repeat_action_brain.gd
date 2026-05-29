## fires an action signal repeatedly on a timer while active
class_name AIRepeatActionBrain extends CDEntityComponent

@export var fire_interval: float = 0.3

@export_group("Listen Signals")
@export var start_signals: Array[StringName] = [&"start_shooting"]
@export var stop_signals: Array[StringName] = [&"stop_shooting"]

@export_group("Emit Signals")
@export var fire_action: StringName = &"shoot"
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

var _timer: float = 0.0
var _is_active: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	# ensure the named action signal exists on entity
	entity.ensure_signal(fire_action)
	var end_signal := StringName(fire_action + &"_end")
	entity.ensure_signal(end_signal)
	
	for sig in action_signals:
		entity.ensure_signal(sig)
	for sig in action_end_signals:
		entity.ensure_signal(sig)
	for sig in start_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_start)
	for sig in stop_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_stop)

func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	_timer += delta
	if _timer >= fire_interval:
		_timer = 0.0
		# emit named signal (e.g., "shoot") for specific arms like GunArm
		entity.emit_signal(fire_action)
		# emit generic signal for catch-all listeners
		for sig in action_signals:
			entity.emit_signal(sig, fire_action)

func _on_start() -> void:
	if _is_active:
		return
	_is_active = true
	_timer = fire_interval  # fire immediately on first activation

func _on_stop() -> void:
	if not _is_active:
		return
	_is_active = false
	_timer = 0.0
	# emit named end signal (e.g., "shoot_end")
	var end_signal := StringName(fire_action + &"_end")
	entity.emit_signal(end_signal)
	# emit generic end signal for catch-all listeners
	for sig in action_end_signals:
		entity.emit_signal(sig, fire_action)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if _is_active:
		_on_stop()
	for sig in start_signals:
		if entity.is_connected(sig, _on_start):
			entity.disconnect(sig, _on_start)
	for sig in stop_signals:
		if entity.is_connected(sig, _on_stop):
			entity.disconnect(sig, _on_stop)
