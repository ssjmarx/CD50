# Grid movement leg. Moves its parent by a fixed step size in response to
# move signals. Uses Godot physics (test_move) for occupancy checks and
# UniversalBody bounds for boundaries. No external grid dependency.

extends UniversalComponent

# Step configuration
@export var step_size: float = 16.0
@export var hop_delay: float = 0.0
@export var allow_diagonal: bool = false

# Occupancy checking via physics
@export var block_on_collision: bool = true

# Direction locks
@export var prevent_movement_up: bool = false
@export var prevent_movement_down: bool = false
@export var prevent_movement_left: bool = false
@export var prevent_movement_right: bool = false

# Hard drop on shoot signal
@export var enable_hard_drop: bool = false

# Input queue configuration
@export var use_input_queue: bool = false
@export var max_queue_size: int = 4

# Runtime state
var _input_queue: Array[Vector2] = []
var _last_input: Vector2 = Vector2.ZERO
var _stored_direction: Vector2 = Vector2.ZERO
var _hop_timer: float = 0.0

# Emitted after a successful step
signal moved

# Connect signals
func _ready() -> void:
	parent.move.connect(_on_move)
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
	
	# Check physics occupancy via test_move
	if block_on_collision and parent.test_move(parent.global_transform, displacement):
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
	
	while true:
		var next_disp = total_displacement + drop_dir * step_size
		if parent.test_move(parent.global_transform, next_disp):
			break
		# Check if the next position would exceed bounds
		var target_y = parent.position.y + next_disp.y
		if target_y < parent.y_min or target_y > parent.y_max:
			break
		total_displacement = next_disp
	
	if total_displacement != Vector2.ZERO:
		parent.move_parent(total_displacement)

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

# Check if a step direction is blocked by direction lock exports
func _is_direction_blocked(step_dir: Vector2) -> bool:
	if step_dir.x < 0 and prevent_movement_left: return true
	if step_dir.x > 0 and prevent_movement_right: return true
	if step_dir.y < 0 and prevent_movement_up: return true
	if step_dir.y > 0 and prevent_movement_down: return true
	return false
