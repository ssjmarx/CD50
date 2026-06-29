## lock_detector_guts.gd
## Produces: piece_locked signal after SRS-style lock delay, with move/rotate reset limits.
## Consumes: direction_key (entity blackboard); step_blocked, moved, rotated signals.

class_name LockDetectorGuts extends CDEntityComponent

## --- exports ---

## seconds before the piece locks after landing
@export var lock_delay: float = 0.5
## max times the lock timer can be reset by moves/rotations
@export var max_resets: int = 15
## direction considered "down" for landing detection
@export var down_direction: Vector2 = Vector2.DOWN

@export_group("Blackboard Keys")
## key to read step direction from
@export var direction_key: StringName = &"step_direction"

## signals that indicate a downward step was blocked
@export_group("Listen Signals")
@export var step_blocked_signals: Array[StringName] = [&"step_blocked"]
## signals that indicate the piece moved (resets lock timer)
@export var move_signals: Array[StringName] = [&"moved"]
## signals that indicate the piece rotated (resets lock timer)
@export var rotate_signals: Array[StringName] = [&"rotated"]

## emitted when the piece locks in place
@export_group("Emit Signals")
@export var piece_locked_signals: Array[StringName] = [&"piece_locked"]

## --- state ---

var _lock_timer: float = 0.0
var _is_locking: bool = false
var _reset_count: int = 0

## --- lifecycle ---

## Set the state component category before the base _ready lifecycle.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## Connect step_blocked, moved, and rotated listeners during initialization.
func _on_initialize() -> void:
	for sig in step_blocked_signals:
		self.bus_connect(sig, _on_step_blocked)
	for sig in move_signals:
		self.bus_connect(sig, _on_moved)
	for sig in rotate_signals:
		self.bus_connect(sig, _on_rotated)

## --- signal handlers ---

## read direction from blackboard; begin lock delay if downward step blocked
func _on_step_blocked() -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction != down_direction:
		return
	if _is_locking:
		return
	
	_is_locking = true
	_lock_timer = lock_delay
	_reset_count = 0

## reset lock timer on move (if within reset limit)
func _on_moved() -> void:
	_try_reset_timer()

## reset lock timer on rotation (if within reset limit)
func _on_rotated() -> void:
	_try_reset_timer()

## --- processing ---

## Tick the lock timer; emit piece_locked when it expires.
func _physics_process(delta: float) -> void:
	if not _is_locking:
		return
	
	_lock_timer -= delta
	if _lock_timer <= 0.0:
		_lock()

## --- helpers ---

## Reset the lock timer on a move/rotate if still under the reset limit.
func _try_reset_timer() -> void:
	if not _is_locking:
		return
	if _reset_count >= max_resets:
		return
	
	_reset_count += 1
	_lock_timer = lock_delay

## Stop locking and emit piece_locked.
func _lock() -> void:
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	
	for sig in piece_locked_signals:
		entity.bus_emit(sig)

## --- cleanup ---

## Disconnect listeners and reset lock state on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	for sig in step_blocked_signals:
		self.bus_disconnect(sig, _on_step_blocked)
	for sig in move_signals:
		self.bus_disconnect(sig, _on_moved)
	for sig in rotate_signals:
		self.bus_disconnect(sig, _on_rotated)
	set_physics_process(false)

## Reset lock state and re-enable physics processing on activation.
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_is_locking = false
	_lock_timer = 0.0
	_reset_count = 0
	set_physics_process(true)