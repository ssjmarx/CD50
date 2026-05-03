# Grid movement leg. Moves its parent by a fixed step size in response to
# move signals. Uses Godot physics (test_move) for occupancy checks and
# UniversalBody bounds for boundaries. No external grid dependency.

extends UniversalComponent

# Step configuration
@export var step_size: float = 18.0
@export var cell_size: float = 17.9  # Physics check size (slightly < tile_size to avoid false positives)
@export var hop_delay: float = 0.0
@export var allow_diagonal: bool = false

# Occupancy checking via physics
@export var block_on_collision: bool = true

# Direction locks
@export var prevent_movement_up: bool = true
@export var prevent_movement_down: bool = false
@export var prevent_movement_left: bool = false
@export var prevent_movement_right: bool = false

# Hard drop on shoot signal
@export var enable_hard_drop: bool = true

# DAS (Delayed Auto Shift) — transforms held input into auto-repeated steps
@export var das_delay: float = 0.0       # Seconds before auto-repeat starts (0 = no DAS)
@export var das_repeat: float = 0.05     # Seconds between repeated steps during DAS

# Input queue configuration
@export var use_input_queue: bool = false
@export var max_queue_size: int = 4

# Runtime state
var _input_queue: Array[Vector2] = []
var _last_input: Vector2 = Vector2.ZERO
var _stored_direction: Vector2 = Vector2.ZERO
var _hop_timer: float = 0.0

# DAS runtime state
var _das_held_direction: Vector2 = Vector2.ZERO
var _das_timer: float = 0.0
var _das_active: bool = false

# Emitted after a successful step
signal moved

# Connect signals
func _ready() -> void:
	parent.move.connect(_on_move)
	if enable_hard_drop:
		parent.shoot.connect(_on_shoot)

# Handle move input: queue or store direction, execute immediately if no hop delay
func _on_move(direction: Vector2) -> void:
	if use_input_queue:
		if direction != _last_input and direction != Vector2.ZERO:
			var step = _direction_to_step(direction)
			if step != Vector2.ZERO and _input_queue.size() < max_queue_size:
				_input_queue.append(step)
		_last_input = direction
		if hop_delay <= 0.0 and not _input_queue.is_empty():
			_execute_queue_hop()
	elif das_delay > 0.0:
		_handle_das_input(direction)
	else:
		_stored_direction = direction
		if hop_delay <= 0.0:
			_execute_hop()

# Process queued inputs, executing the first valid step
func _execute_queue_hop() -> void:
	while not _input_queue.is_empty():
		var step_dir = _input_queue.pop_front()
		if _try_step(step_dir):
			return

# Tick the hop timer and DAS timer, execute moves when intervals elapse
func _process(delta: float) -> void:
	# Hop delay timer
	if hop_delay > 0.0:
		_hop_timer += delta
		if _hop_timer >= hop_delay:
			if use_input_queue:
				_execute_queue_hop()
			elif _stored_direction != Vector2.ZERO:
				_execute_hop()
			_hop_timer = 0.0
	
	# DAS auto-repeat timer
	if das_delay > 0.0 and _das_held_direction != Vector2.ZERO:
		_das_timer += delta
		if _das_active:
			if _das_timer >= das_repeat:
				_das_timer = 0.0
				_try_step(_direction_to_step(_das_held_direction))
		elif _das_timer >= das_delay:
			_das_active = true
			_das_timer = 0.0
			_try_step(_direction_to_step(_das_held_direction))

# --- DAS Input ---

# Handle DAS-aware input: immediate step on new direction, track for auto-repeat
func _handle_das_input(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		_das_held_direction = Vector2.ZERO
		_das_timer = 0.0
		_das_active = false
		return
	
	if direction != _das_held_direction:
		_das_held_direction = direction
		_das_timer = 0.0
		_das_active = false
		# Immediate step on new direction press
		_try_step(_direction_to_step(direction))

# --- Hop Execution ---

# Execute a stored-direction hop: validate and move one step, then clear direction
func _execute_hop() -> void:
	if _stored_direction == Vector2.ZERO:
		return
	
	var step_dir = _direction_to_step(_stored_direction)
	if step_dir == Vector2.ZERO:
		return
	
	_try_step(step_dir)
	_stored_direction = Vector2.ZERO

# Attempt to move one step in the given direction
func _try_step(step_dir: Vector2) -> bool:
	if _is_direction_blocked(step_dir):
		return false
	
	var displacement = step_dir * step_size
	
	if not _can_move_to(displacement):
		return false
	
	parent.move_parent(displacement)
	moved.emit()
	return true

# --- Hard Drop ---

# Instantly drop to the lowest unobstructed position on shoot signal
func _on_shoot() -> void:
	if not enable_hard_drop:
		return
	
	var drop_dir = Vector2.DOWN
	var total_displacement = Vector2.ZERO
	var max_drops = 40
	
	while max_drops > 0:
		max_drops -= 1
		var next_disp = total_displacement + drop_dir * step_size
		
		if not _can_move_to(next_disp):
			break
		
		total_displacement = next_disp
	
	if total_displacement != Vector2.ZERO:
		parent.move_parent(total_displacement)

# --- Movement Validation ---

# Unified movement check. For multi-cell bodies, checks each offset cell individually
# for bounds + physics occupancy (per-cell intersect_point). For single-cell bodies,
# falls back to test_move (existing behavior, zero impact on non-Tetris games).
func _can_move_to(displacement: Vector2) -> bool:
	# Multi-cell body: per-cell bounds + per-cell occupancy
	if "current_offsets" in parent and parent.current_offsets.size() > 0:
		var space_state = parent.get_world_2d().direct_space_state
		for offset in parent.current_offsets:
			var cell_pos: Vector2 = parent.global_position + displacement + Vector2(offset.x * step_size, offset.y * step_size)
			# Bounds check
			if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
				return false
			if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
				return false
			# Physics occupancy check (per-cell shape query)
			if block_on_collision:
				if _is_cell_occupied(space_state, cell_pos):
					return false
		return true
	
	# Single-cell body: bounds check + test_move
	var target_pos = parent.global_position + displacement
	if target_pos.x < parent.x_min or target_pos.x > parent.x_max:
		return false
	if target_pos.y < parent.y_min or target_pos.y > parent.y_max:
		return false
	if block_on_collision and parent.test_move(parent.global_transform, displacement):
		return false
	return true

# --- Utility ---

# Convert a continuous direction vector to a discrete step direction
func _direction_to_step(dir: Vector2) -> Vector2:
	if allow_diagonal and abs(dir.x) > 0.5 and abs(dir.y) > 0.5:
		return Vector2(1.0 if dir.x > 0 else -1.0, 1.0 if dir.y > 0 else -1.0)
	elif abs(dir.x) > abs(dir.y):
		return Vector2(1.0 if dir.x > 0 else -1.0, 0.0)
	elif abs(dir.y) > abs(dir.x):
		return Vector2(0.0, 1.0 if dir.y > 0 else -1.0)
	return Vector2.ZERO

# Check if a cell position is occupied by another physics body using a shape query.
# Uses a rectangle of cell_size x cell_size instead of a point for robust wall detection.
func _is_cell_occupied(space_state: PhysicsDirectSpaceState2D, cell_pos: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, cell_pos)
	query.collision_mask = parent.collision_mask
	query.exclude = [parent.get_rid()]
	return space_state.intersect_shape(query).size() > 0

# Check if a step direction is blocked by direction lock exports
func _is_direction_blocked(step_dir: Vector2) -> bool:
	if step_dir.x < 0 and prevent_movement_left: return true
	if step_dir.x > 0 and prevent_movement_right: return true
	if step_dir.y < 0 and prevent_movement_up: return true
	if step_dir.y > 0 and prevent_movement_down: return true
	return false
