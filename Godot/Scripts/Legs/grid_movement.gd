# Grid movement leg. Moves an entity cell-by-cell on a grid, supporting
# hop delays, input queuing, direction locks, formation checks, and hard drop.

extends UniversalComponent

# Movement timing and input mode
@export var hop_delay: float = 0.0
@export var grid_group: String = "grid"
@export var allow_diagonal: bool = false
@export var block_on_occupied: bool = true
@export var use_input_queue: bool = false
@export var max_queue_size: int = 4

# Direction lock configuration
@export var prevent_movement_up: bool = false
@export var prevent_movement_down: bool = false
@export var prevent_movement_left: bool = false
@export var prevent_movement_right: bool = false

# Hard drop on shoot signal
@export var enable_hard_drop: bool = false

# Runtime state
var _input_queue: Array[Vector2i] = []
var _last_input: Vector2 = Vector2.ZERO
var _grid: Node2D
var _current_cell: Vector2i = Vector2i(-1, -1)
var _stored_direction: Vector2 = Vector2.ZERO
var _hop_timer: float = 0.0

# Emitted after a successful grid move
signal moved

# Find grid, connect signals, defer cell initialization
func _ready() -> void:
	_grid = _find_nearest_grid()
	parent.move.connect(_on_move)
	parent.shoot.connect(_on_shoot)
	call_deferred("_init_cell")

# Snap parent to the nearest grid cell on first frame
func _init_cell() -> void:
	if _grid:
		_current_cell = _grid.world_to_grid(parent.global_position)

# Handle move input: queue or store direction, execute immediately if no hop delay
func _on_move(direction: Vector2) -> void:
	if use_input_queue:
		if direction != _last_input and direction != Vector2.ZERO:
			var step = _direction_to_step(direction)
			if step != Vector2i.ZERO and _input_queue.size() < max_queue_size:
				_input_queue.append(step)
		_last_input = direction
		if hop_delay <= 0.0 and not _input_queue.is_empty():
			_execute_queue_hop()
	else:
		_stored_direction = direction
		if hop_delay <= 0.0:
			_execute_hop()

# Process queued inputs, executing the first valid step
func _execute_queue_hop() -> void:
	while not _input_queue.is_empty():
		var step = _input_queue.pop_front()
		if _try_step(step):
			return

# Attempt to move one cell in the given step direction
func _try_step(step: Vector2i) -> bool:
	if _is_direction_blocked(step):
		return false
	var target = _current_cell + step
	if not _grid.is_valid_cell(target.y, target.x):
		return false
	if block_on_occupied and _grid.is_occupied(target.y, target.x):
		return false
	if not _can_formation_move(step):
		return false
	_current_cell = target
	parent.global_position = _grid.grid_to_world(_current_cell.y, _current_cell.x)
	return true

# Tick the hop timer and execute moves when the interval elapses
func _process(delta: float) -> void:
	if hop_delay > 0.0:
		_hop_timer += delta
		if _hop_timer >= hop_delay:
			if use_input_queue:
				_execute_queue_hop()
			elif _stored_direction != Vector2.ZERO:
				_execute_hop()
			_hop_timer = 0.0

# --- Grid Lookup ---

# Find the nearest grid node in the scene tree by distance
func _find_nearest_grid() -> Node2D:
	var grids = get_group_nodes("grid")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for grid in grids:
		var dist = parent.global_position.distance_to(grid.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = grid
	return nearest

# --- Hop Execution ---

# Execute a stored-direction hop: validate and move one cell, then clear direction
func _execute_hop() -> void:
	if _stored_direction == Vector2.ZERO:
		return
	if not _grid:
		return
	
	var step = _direction_to_step(_stored_direction)
	if step == Vector2i.ZERO:
		return
	
	if _is_direction_blocked(step):
		return
	
	var target = _current_cell + step
	
	if not _grid.is_valid_cell(target.y, target.x):
		return
	
	if block_on_occupied and _grid.is_occupied(target.y, target.x):
		return
	
	if not _can_formation_move(step):
		return
	
	_current_cell = target
	parent.global_position = _grid.grid_to_world(_current_cell.y, _current_cell.x)
	_stored_direction = Vector2.ZERO
	moved.emit()

# --- Utility ---

# Convert a continuous direction vector to a discrete grid step
func _direction_to_step(dir: Vector2) -> Vector2i:
	var step = Vector2i.ZERO
	
	if allow_diagonal and abs(dir.x) > 0.5 and abs(dir.y) > 0.5:
		step.x = 1 if dir.x > 0 else -1
		step.y = 1 if dir.y > 0 else -1
	elif abs(dir.x) > abs(dir.y):
		step.x = 1 if dir.x > 0 else -1 if dir.x < 0 else 0
	elif abs(dir.y) > abs(dir.x):
		step.y = 1 if dir.y > 0 else -1 if dir.y < 0 else 0
	
	return step

# Check if a step direction is blocked by direction lock exports
func _is_direction_blocked(step: Vector2i) -> bool:
	if step.x < 0 and prevent_movement_left: return true
	if step.x > 0 and prevent_movement_right: return true
	if step.y < 0 and prevent_movement_up: return true
	if step.y > 0 and prevent_movement_down: return true
	return false

# Ask child components if the formation allows movement in the given step
func _can_formation_move(step: Vector2i) -> bool:
	for child in parent.get_children():
		if child.has_method("can_move_on_grid"):
			if not child.can_move_on_grid(step):
				return false
	return true

# --- Hard Drop ---

# Instantly drop to the lowest unobstructed cell on shoot signal
func _on_shoot() -> void:
	if not enable_hard_drop or not _grid:
		return
	
	var drop_cell = _current_cell
	while true:
		var next = drop_cell + Vector2i(0, 1)
		if not _grid.is_valid_cell(next.y, next.x):
			break
		if _grid.is_occupied(next.y, next.x):
			break
		if not _can_formation_move(drop_cell + Vector2i(0, 1)):
			break
		drop_cell = next
	
	_current_cell = drop_cell
	parent.global_position = _grid.grid_to_world(_current_cell.y, _current_cell.x)

# Return the current grid cell coordinates
func get_current_cell() -> Vector2i:
	return _current_cell
