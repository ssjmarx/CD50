 # Lock detector component. Detects when a multi-cell body can't fall further,
# manages lock delay, and emits settlement signals. Does NOT handle spawning
# or splitting — that's tetromino_spawner's job.

extends UniversalComponent

# Lock timing
@export var lock_delay: float = 0.5
@export var fall_direction: Vector2 = Vector2.DOWN
@export var step_size: float = 18.0
@export var cell_size: float = 17.9  # Physics check size (slightly < tile_size to avoid false positives)

# Maximum lock timer resets from moves/rotations while grounded.
# 0 = no limit (classic behavior). 15 = Guideline standard.
@export var max_lock_resets: int = 15

# Emitted immediately before piece_locked, while the multi-cell body still exists.
# Use for T-spin detection and other pre-lock checks.
signal piece_pre_lock(cell_positions: Array[Vector2])

# Emitted when the piece locks — provides world positions of each cell
signal piece_locked(cell_positions: Array[Vector2])

# Emitted if the piece escapes the floor while locking (edge case)
signal lock_cancelled

# Runtime state
var _is_locking: bool = false
var _lock_timer: float = 0.0
var _lock_reset_count: int = 0
var _movement_leg: Node = null
var _rotation_leg: Node = null

# Find sibling movement and rotation legs for lock timer reset
func _ready() -> void:
	# Defer to allow siblings to be ready
	call_deferred("_find_sibling_legs")

func _find_sibling_legs() -> void:
	for child in parent.get_children():
		if child.has_signal("moved") and child != self:
			_movement_leg = child
			child.moved.connect(_on_piece_moved)
		if child.has_signal("rotated"):
			_rotation_leg = child
			child.rotated.connect(_on_piece_rotated)

# Check floor each frame, manage lock delay countdown
func _process(delta: float) -> void:
	if _is_locking:
		# Check if piece can now fall (moved off floor somehow)
		if not _is_on_floor():
			_is_locking = false
			_lock_timer = 0.0
			_lock_reset_count = 0
			lock_cancelled.emit()
			return
		
		_lock_timer += delta
		if _lock_timer >= lock_delay:
			_execute_lock()
	else:
		# Check if piece just landed
		if _is_on_floor():
			_is_locking = true
			_lock_timer = 0.0
			_lock_reset_count = 0

# Check if body cannot move one step in the fall direction
func _is_on_floor() -> bool:
	var displacement = fall_direction * step_size
	return not _can_fall(displacement)

# Check if the body can fall one step — tests bounds AND physics occupancy.
# Mirrors grid_gravity._can_move() so lock detection stays in sync with gravity.
func _can_fall(displacement: Vector2) -> bool:
	# Multi-cell body: check each offset cell for bounds + occupancy
	if "current_offsets" in parent and parent.current_offsets.size() > 0:
		var space_state = parent.get_world_2d().direct_space_state
		for offset in parent.current_offsets:
			var cell_pos: Vector2 = parent.global_position + displacement + Vector2(offset.x * step_size, offset.y * step_size)
			# Bounds check
			if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
				return false
			if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
				return false
			# Physics occupancy check (shape query for robust wall detection)
			if _is_cell_occupied(space_state, cell_pos):
				return false
		return true
	
	# Single-cell body: test_move + bounds
	if parent.test_move(parent.global_transform, displacement):
		return false
	var target_y = parent.position.y + displacement.y
	if target_y < parent.y_min or target_y > parent.y_max:
		return false
	return true

# Lock the piece: compute cell positions and emit
func _execute_lock() -> void:
	# Prevent further processing
	set_process(false)
	
	var cell_positions: Array[Vector2] = []
	
	# If parent has offsets (multi-cell body), compute world positions
	if "current_offsets" in parent:
		for offset in parent.current_offsets:
			var world_pos = parent.global_position + Vector2(offset.x * step_size, offset.y * step_size)
			cell_positions.append(world_pos)
	else:
		# Single cell body — just use parent position
		cell_positions.append(parent.global_position)
	
	# Emit pre-lock signal first (T-spin detector listens here)
	piece_pre_lock.emit(cell_positions)
	piece_locked.emit(cell_positions)

# Reset lock timer when the piece moves laterally
func _on_piece_moved() -> void:
	if _is_locking:
		_lock_reset_count += 1
		if max_lock_resets > 0 and _lock_reset_count > max_lock_resets:
			_execute_lock()
			return
		_lock_timer = 0.0

# Reset lock timer when the piece rotates
func _on_piece_rotated() -> void:
	if _is_locking:
		_lock_reset_count += 1
		if max_lock_resets > 0 and _lock_reset_count > max_lock_resets:
			_execute_lock()
			return
		_lock_timer = 0.0

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

# Clean up signal connections on removal
func _exit_tree() -> void:
	if _movement_leg and is_instance_valid(_movement_leg):
		if _movement_leg.has_signal("moved"):
			_movement_leg.moved.disconnect(_on_piece_moved)
	if _rotation_leg and is_instance_valid(_rotation_leg):
		if _rotation_leg.has_signal("rotated"):
			_rotation_leg.rotated.disconnect(_on_piece_rotated)
