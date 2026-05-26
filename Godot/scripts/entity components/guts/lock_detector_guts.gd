## detects when a grid entity can't fall further, manages lock delay
class_name LockDetectorGuts extends CDEntityComponent

@export var lock_delay: float = 0.5
@export var max_resets: int = 15
@export var down_direction: Vector2 = Vector2.DOWN

@export_group("Listen Signals")
@export var step_blocked_signals: Array[StringName] = [&"step_blocked"]
@export var move_signals: Array[StringName] = [&"moved"]
@export var rotate_signals: Array[StringName] = [&"rotated"]

@export_group("Emit Signals")
@export var piece_locked_signals: Array[StringName] = [&"piece_locked"]

var _lock_timer: float = 0.0
var _is_locking: bool = false
var _reset_count: int = 0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in step_blocked_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_step_blocked)
	
	for sig in move_signals:
		entity.connect(sig, _on_moved)
	
	for sig in rotate_signals:
		entity.connect(sig, _on_rotated)

func _on_step_blocked(direction: Vector2) -> void:
	if direction != down_direction:
		return
	if _is_locking:
		return
	
	_is_locking = true
	_lock_timer = lock_delay
	_reset_count = 0

func _on_moved(_old_pos: Vector2, _new_pos: Vector2) -> void:
	_try_reset_timer()

func _on_rotated(_old_rot: float, _new_rot: float) -> void:
	_try_reset_timer()

func _try_reset_timer() -> void:
	if not _is_locking:
		return
	if _reset_count >= max_resets:
		return
	
	_reset_count += 1
	_lock_timer = lock_delay

func _physics_process(delta: float) -> void:
	if not _is_locking:
		return
	
	_lock_timer -= delta
	if _lock_timer <= 0.0:
		_lock()

func _lock() -> void:
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	
	for sig in piece_locked_signals:
		entity.emit_signal(sig)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	for sig in step_blocked_signals:
		if entity.is_connected(sig, _on_step_blocked):
			entity.disconnect(sig, _on_step_blocked)
	for sig in move_signals:
		if entity.is_connected(sig, _on_moved):
			entity.disconnect(sig, _on_moved)
	for sig in rotate_signals:
		if entity.is_connected(sig, _on_rotated):
			entity.disconnect(sig, _on_rotated)
	set_physics_process(false)

func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	set_physics_process(true)
