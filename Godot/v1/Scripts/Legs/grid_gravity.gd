# Grid gravity leg. Timer-based downward movement as a direct force.
# Bypasses the Brain→Body→Leg signal chain — calls parent.move_parent() directly.
# Gravity is a world force, not input.

extends UniversalComponent

# Configuration
@export var fall_interval: float = 1.0     # Seconds between gravity steps
@export var step_size: float = 18.0        # Must match grid_movement.step_size and body tile_size
@export var cell_size: float = 17.9        # Physics check size (slightly < tile_size to avoid false positives)
@export var paused: bool = false           # Freeze gravity (during line clear, game pause, etc.)

# Signals
signal grounded    # Emitted when gravity can't move the body down (floor or obstacle)
signal fell        # Emitted after each successful gravity step (resets lock_detector timer)

# Runtime state
var _timer: float = 0.0

func _process(delta: float) -> void:
	if paused:
		return
	
	_timer += delta
	if _timer < fall_interval:
		return
	
	_timer = 0.0
	_attempt_step()

# Attempt one gravity step downward
func _attempt_step() -> void:
	var displacement := Vector2.DOWN * step_size
	
	if not _can_move(displacement):
		grounded.emit()
		return
	
	parent.move_parent(displacement)
	fell.emit()

# Check if the body can move by the given displacement.
# For multi-cell bodies (with current_offsets), check ALL cells.
# For single-cell bodies, use test_move().
func _can_move(displacement: Vector2) -> bool:
	# Multi-cell body: check each offset cell for occupancy + bounds
	if "current_offsets" in parent and parent.current_offsets.size() > 0:
		return _can_move_multi_cell(displacement)
	
	# Single-cell body: simple test_move + bounds
	if parent.test_move(parent.global_transform, displacement):
		return false
	
	var target_y = parent.position.y + displacement.y
	if target_y < parent.y_min or target_y > parent.y_max:
		return false
	
	return true

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

# Check all offset cells for occupancy and bounds after applying displacement
func _can_move_multi_cell(displacement: Vector2) -> bool:
	var offsets: Array = parent.current_offsets
	
	for offset in offsets:
		var cell_world_pos: Vector2 = parent.global_position + displacement + Vector2(offset.x * step_size, offset.y * step_size)
		
		# Bounds check for this cell
		if cell_world_pos.x < parent.x_min or cell_world_pos.x > parent.x_max:
			return false
		if cell_world_pos.y < parent.y_min or cell_world_pos.y > parent.y_max:
			return false
		
		# Physics occupancy check via intersect_shape
		var space_state = parent.get_world_2d().direct_space_state
		if _is_cell_occupied(space_state, cell_world_pos):
			return false
	
	return true
