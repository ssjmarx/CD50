# LockDetectorGuts
# Detects when a grid entity can't fall further and manages lock delay
# Implements SRS-style lock delay with move/rotate reset limits (Tetris)

class_name LockDetectorGuts extends CDEntityComponent

# --- exports ---

# seconds before the piece locks after landing
@export var lock_delay: float = 0.5
# max times the lock timer can be reset by moves/rotations
@export var max_resets: int = 15
# direction considered "down" for landing detection
@export var down_direction: Vector2 = Vector2.DOWN

# signals that indicate a downward step was blocked
@export_group("Listen Signals")
@export var step_blocked_signals: Array[StringName] = [&"step_blocked"]
# signals that indicate the piece moved (resets lock timer)
@export var move_signals: Array[StringName] = [&"moved"]
# signals that indicate the piece rotated (resets lock timer)
@export var rotate_signals: Array[StringName] = [&"rotated"]

# emitted when the piece locks in place
@export_group("Emit Signals")
@export var piece_locked_signals: Array[StringName] = [&"piece_locked"]

# --- state ---

# countdown to lock
var _lock_timer: float = 0.0
# whether the piece is currently in lock delay
var _is_locking: bool = false
# how many times the timer has been reset
var _reset_count: int = 0

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

# connect step_blocked, move, and rotate listeners
func _on_initialize() -> void:
	for sig in step_blocked_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_step_blocked)
	
	for sig in move_signals:
		entity.connect(sig, _on_moved)
	
	for sig in rotate_signals:
		entity.connect(sig, _on_rotated)

# --- signal handlers ---

# begin lock delay when downward step is blocked
func _on_step_blocked(direction: Vector2) -> void:
	if direction != down_direction:
		return
	if _is_locking:
		return
	
	_is_locking = true
	_lock_timer = lock_delay
	_reset_count = 0

# reset lock timer on move (if within reset limit)
func _on_moved(_old_pos: Vector2, _new_pos: Vector2) -> void:
	_try_reset_timer()

# reset lock timer on rotation (if within reset limit)
func _on_rotated(_old_rot: float, _new_rot: float) -> void:
	_try_reset_timer()

# --- processing ---

# tick lock timer and lock the piece when it expires
func _physics_process(delta: float) -> void:
	if not _is_locking:
		return
	
	_lock_timer -= delta
	if _lock_timer <= 0.0:
		_lock()

# --- helpers ---

# reset lock timer if currently locking and under max resets
func _try_reset_timer() -> void:
	if not _is_locking:
		return
	if _reset_count >= max_resets:
		return
	
	_reset_count += 1
	_lock_timer = lock_delay

# emit piece_locked and reset state
func _lock() -> void:
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	
	for sig in piece_locked_signals:
		entity.emit_signal(sig)

# --- cleanup ---

# reset state and disconnect all signals for pool reuse
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

# reset state on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	set_physics_process(true)