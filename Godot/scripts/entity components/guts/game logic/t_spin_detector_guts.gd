## TSpinDetectorGuts
## Uses the SRS 3-corner rule to detect T-spins when a T-shaped piece locks
## Checks 4 diagonal corners after last rotation; 3+ occupied = T-spin

class_name TSpinDetectorGuts extends CDEntityComponent

## --- exports ---

## distance from entity center to cast for corner occupancy
@export var corner_cast_distance: float = 10.0

## signals that indicate the piece locked (triggers detection check)
@export_group("Listen Signals")
@export var lock_signals: Array[StringName] = [&"piece_locked"]
## signals that track rotation state (must rotate before lock for T-spin)
@export var rotate_signals: Array[StringName] = [&"rotated"]

## game bus signals emitted on detection (bool is_t_spin, bool is_mini)
@export_group("Emit Signals (Game Bus)")
@export var t_spin_signals: Array[StringName] = [&"t_spin_detected"]

## --- state ---

## whether the piece was rotated since last lock
var _last_rotated: bool = false
## current rotation state (0-3, mapped from global_rotation)
var _rotation_state: int = 0

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## calculate initial rotation state and connect listeners
func _on_initialize() -> void:
	_rotation_state = int(round(entity.global_rotation / (PI / 2))) % 4
	if _rotation_state < 0:
		_rotation_state += 4
	
	for sig in lock_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_piece_locked)
	
	for sig in rotate_signals:
		entity.connect(sig, _on_rotated)

## --- signal handlers ---

## track rotation state and flag that a rotation occurred
func _on_rotated(_old_rot: float, new_rot: float) -> void:
	_last_rotated = true
	_rotation_state = int(round(new_rot / (PI / 2))) % 4
	if _rotation_state < 0:
		_rotation_state += 4

## check corners using 3-corner rule if piece was last rotated
func _on_piece_locked() -> void:
	if not _last_rotated:
		_announce(false, false)
		return
	
	var pos = entity.global_position
	var d = corner_cast_distance
	
	var corner_offsets: Array[Vector2] = [
		Vector2(-d, -d),
		Vector2(d, -d),
		Vector2(-d, d),
		Vector2(d, d),
	]
	
	## check occupancy of each corner
	var corners: Array[bool] = [false, false, false, false]
	var corners_hit: int = 0
	for i in range(4):
		corners[i] = _is_corner_occupied(pos + corner_offsets[i])
		if corners[i]:
			corners_hit += 1
	
	## need at least 3 corners occupied for any T-spin
	if corners_hit < 3:
		_announce(false, false)
		_last_rotated = false
		return
	
	## determine "back" corners based on rotation state
	var back_a: int
	var back_b: int
	match _rotation_state:
		0:  back_a = 2; back_b = 3
		1:  back_a = 0; back_b = 2
		2:  back_a = 0; back_b = 1
		3:  back_a = 1; back_b = 3
	
	var is_full: bool = corners[back_a] and corners[back_b]
	_announce(true, not is_full)
	_last_rotated = false

## --- helpers ---

## check if a world position is occupied by any physics body
func _is_corner_occupied(pos: Vector2) -> bool:
	var space_state = entity.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = entity.collision_mask
	query.exclude = [entity.get_rid()]
	var result = space_state.intersect_point(query)
	return result.size() > 0

## broadcast T-spin result on the game bus
func _announce(is_t_spin: bool, is_mini: bool) -> void:
	if game:
		for sig in t_spin_signals:
			game.bus_emit(sig, [is_t_spin, is_mini])

## --- cleanup ---

## reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_last_rotated = false
	_rotation_state = 0
	for sig in lock_signals:
		if entity.is_connected(sig, _on_piece_locked):
			entity.disconnect(sig, _on_piece_locked)
	for sig in rotate_signals:
		if entity.is_connected(sig, _on_rotated):
			entity.disconnect(sig, _on_rotated)
	set_physics_process(false)

## reset state on reactivation
func _on_entity_activated() -> void:
	super._on_entity_activated()
	_last_rotated = false
	_rotation_state = 0
