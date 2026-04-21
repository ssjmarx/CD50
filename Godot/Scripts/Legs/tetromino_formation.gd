# Tetromino formation leg. Handles grid-based movement, DAS auto-repeat,
# rotation with wall kicks, lock delay, and hard drop for Tetris pieces.

extends UniversalComponent

enum FallDirection { DOWN, UP, LEFT, RIGHT }

# Fall and timing configuration
@export var fall_direction: FallDirection = FallDirection.DOWN
@export var fall_interval: float = 1.0
@export var lock_delay: float = 0.5
@export var das_delay: float = 0.2
@export var das_repeat: float = 0.05

# Direction lock configuration (disable movement in specific directions)
@export var lock_input_up: bool = true
@export var lock_input_down: bool = false
@export var lock_input_left: bool = false
@export var lock_input_right: bool = false

# Grid state
var _grid: Node2D
var _core_cell: Vector2i = Vector2i(-1, -1)
var _offsets: Array[Vector2i] = []
var _base_offsets: Array[Vector2i] = []

# Fall and lock timers
var _fall_timer: float = 0.0
var _lock_timer: float = 0.0
var _is_locking: bool = false
var _is_locked: bool = false

# DAS (Delayed Auto Shift) state
var _held_direction: Vector2 = Vector2.ZERO
var _das_timer: float = 0.0
var _das_active: bool = false

# Emitted when a piece locks in place; listened to by line_clear_monitor
signal piece_locked
# Emitted with the settled cell positions after locking
signal piece_settled(cells: Array[Vector2i])

# Connect signals and initialize grid position
func _ready() -> void:
	_grid = get_tree().get_first_node_in_group("grid")
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.shoot.connect(_on_shoot)
	
	_base_offsets = _get_typed_offsets(parent.shape)
	_offsets = _base_offsets.duplicate()
	
	call_deferred("_init_position")

# Snap parent to grid cell on first frame (after grid is ready)
func _init_position() -> void:
	if _grid:
		_core_cell = _grid.world_to_grid(parent.global_position)
		parent.global_position = _grid.grid_to_world(_core_cell.y, _core_cell.x)

# Handle auto-fall, floor detection, DAS, and lock delay each frame
func _process(delta: float) -> void:
	if _is_locked: return
	
	# Auto-fall
	_fall_timer += delta
	if _fall_timer >= fall_interval:
		_fall_timer = 0.0
		_try_move(_get_fall_step())
	
	# Floor detection — start or cancel locking
	if _is_on_floor():
		if not _is_locking:
			_is_locking = true
			_lock_timer = 0.0
	else:
		if _is_locking:
			_is_locking = false
			_lock_timer = 0.0
	
	# DAS (held direction auto-repeat)
	if _held_direction != Vector2.ZERO:
		_das_timer += delta
		if _das_active:
			if _das_timer >= das_repeat:
				_das_timer = 0.0
				_try_step(_held_direction)
		elif _das_timer >= das_delay:
			_das_active = true
			_das_timer = 0.0
			_try_step(_held_direction)
	
	# Lock delay countdown
	if _is_locking:
		_lock_timer += delta
		if _lock_timer >= lock_delay:
			_lock_piece()

# --- Movement ---

# Handle directional input; immediate step on new direction, track for DAS
func _on_move(direction: Vector2) -> void:
	if _is_locked: return
	
	if direction == Vector2.ZERO:
		_held_direction = Vector2.ZERO
		_das_timer = 0.0
		_das_active = false
		return
	
	if direction != _held_direction:
		_held_direction = direction
		_das_timer = 0.0
		_das_active = false
		_try_step(direction)

# Convert direction to grid step and attempt move
func _try_step(direction: Vector2) -> void:
	var step = _direction_to_step(direction)
	if step != Vector2i.ZERO:
		_try_move(step)

# Move one grid step if all target cells are valid and unoccupied
func _try_move(step: Vector2i) -> bool:
	var target_cells = _get_target_cells(step)
	
	for cell in target_cells:
		if not _grid.is_valid_cell(cell.y, cell.x):
			return false
		if _grid.is_occupied(cell.y, cell.x):
			return false
	
	_core_cell += step
	parent.global_position = _grid.grid_to_world(_core_cell.y, _core_cell.x)
	
	# Reset lock timer on successful horizontal move
	if step != _get_fall_step() and _is_locking:
		_lock_timer = 0.0
	
	return true

# Return all cell positions after applying a step offset
func _get_target_cells(step: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in _offsets:
		cells.append(_core_cell + offset + step)
	return cells

# Return current cell positions (no step offset)
func _get_current_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in _offsets:
		cells.append(_core_cell + offset)
	return cells

# --- Rotation ---

# Rotate clockwise on thrust signal
func _on_thrust() -> void:
	if _is_locked: return
	_try_rotate(true)

# Attempt rotation with wall kick fallbacks; resets lock timer on success
func _try_rotate(clockwise: bool) -> bool:
	var rotated = _get_rotated_offsets(clockwise)
	
	if _can_place(rotated):
		_offsets = rotated
		parent.update_offsets(_offsets)
		if _is_locking: _lock_timer = 0.0
		return true
	
	# Wall kicks — try shifting the piece to fit
	for kick in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-2,0), Vector2i(2,0)]:
		var kicked: Array[Vector2i] = []
		for offset in rotated:
			kicked.append(offset + kick)
		if _can_place(kicked):
			_offsets = kicked
			_core_cell += kick
			parent.global_position = _grid.grid_to_world(_core_cell.y, _core_cell.x)
			parent.update_offsets(_offsets)
			if _is_locking: _lock_timer = 0.0
			return true
	
	return false

# Rotate all offsets 90 degrees around the core cell
func _get_rotated_offsets(clockwise: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in _offsets:
		if clockwise:
			result.append(Vector2i(-offset.y, offset.x))
		else:
			result.append(Vector2i(offset.y, -offset.x))
	return result

# Check if all offsets can be placed at the current core cell
func _can_place(test_offsets: Array[Vector2i]) -> bool:
	for offset in test_offsets:
		var cell = _core_cell + offset
		if not _grid.is_valid_cell(cell.y, cell.x):
			return false
		if _grid.is_occupied(cell.y, cell.x):
			return false
	return true

# --- Locking ---

# Lock the piece in place, register cells on the grid, emit signals
func _lock_piece() -> void:
	_is_locked = true
	_held_direction = Vector2.ZERO
	
	# Remove brain/AI nodes — settled pieces don't need them
	for child in parent.get_children():
		var child_name = child.name.to_lower()
		if "player" in child_name or "_ai" in child_name:
			child.queue_free()
	
	for cell in _get_current_cells():
		_grid.register_cell(cell.y, cell.x, parent)
	
	piece_locked.emit()
	piece_settled.emit(_get_current_cells())

# Check if the piece cannot fall further
func _is_on_floor() -> bool:
	return not _can_place_with_step(_get_fall_step())

# Check if all cells are valid and unoccupied after a step
func _can_place_with_step(step: Vector2i) -> bool:
	for offset in _offsets:
		var cell = _core_cell + offset + step
		if not _grid.is_valid_cell(cell.y, cell.x):
			return false
		if _grid.is_occupied(cell.y, cell.x):
			return false
	return true

# --- Hard Drop ---

# Instantly drop the piece to the lowest valid position and lock
func _on_shoot() -> void:
	if _is_locked: return
	while _can_place_with_step(_get_fall_step()):
		_core_cell += _get_fall_step()
	parent.global_position = _grid.grid_to_world(_core_cell.y, _core_cell.x)
	_lock_piece()

# --- Utility ---

# Convert a continuous direction to a discrete grid step, respecting direction locks
func _direction_to_step(dir: Vector2) -> Vector2i:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0 and lock_input_right: return Vector2i.ZERO
		if dir.x < 0 and lock_input_left: return Vector2i.ZERO
		return Vector2i(1 if dir.x > 0 else -1, 0)
	elif abs(dir.y) > abs(dir.x):
		if dir.y > 0 and lock_input_down: return Vector2i.ZERO
		if dir.y < 0 and lock_input_up: return Vector2i.ZERO
		return Vector2i(0, 1 if dir.y > 0 else -1)
	return Vector2i.ZERO

# Copy shape offsets from the parent body into a typed array
func _get_typed_offsets(shape_key) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(parent.SHAPE_OFFSETS[shape_key])
	return result

# Return the grid step vector for the current fall direction
func _get_fall_step() -> Vector2i:
	match fall_direction:
		FallDirection.DOWN: return Vector2i(0, 1)
		FallDirection.UP: return Vector2i(0, -1)
		FallDirection.LEFT: return Vector2i(-1, 0)
		FallDirection.RIGHT: return Vector2i(1, 0)
	return Vector2i(0, 1)
