# T-spin detector component. Uses the SRS 3-corner rule to detect T-spins
# when a T-shaped piece locks after a rotation. Emits result via game signal.

extends UniversalComponent

# Grid spacing. Must match grid_movement.step_size.
@export var step_size: float = 18.0

# Physics check size (slightly < tile_size to avoid false positives)
@export var cell_size: float = 17.9

# Track whether the last action was a rotation (required for T-spin)
var _last_was_rotation: bool = false

func _ready() -> void:
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	# Listen to sibling leg signals to track rotation state
	for child in parent.get_children():
		if child == self:
			continue
		if child.has_signal("moved"):
			child.moved.connect(_on_piece_moved)
		if child.has_signal("rotated"):
			child.rotated.connect(_on_piece_rotated)
	
	# Listen to lock detector's pre-lock signal
	for child in parent.get_children():
		if child == self:
			continue
		if child.has_signal("piece_pre_lock"):
			child.piece_pre_lock.connect(_on_piece_pre_lock)

# --- Signal Handlers ---

func _on_piece_moved() -> void:
	_last_was_rotation = false

func _on_piece_rotated() -> void:
	_last_was_rotation = true

func _on_piece_pre_lock(_cell_positions: Array[Vector2]) -> void:
	_check_t_spin()

# --- T-Spin Detection ---

func _check_t_spin() -> void:
	# Only applies to T-pieces after a rotation
	if not _is_t_piece():
		game.t_spin_detected.emit(false, false)
		return
	
	if not _last_was_rotation:
		game.t_spin_detected.emit(false, false)
		return
	
	# Count occupied corners
	var corner_data = _evaluate_corners()
	var total_occupied: int = corner_data["front"] + corner_data["back"]
	
	var is_t_spin: bool = false
	var is_mini: bool = false
	
	if total_occupied >= 3:
		is_t_spin = true
	elif corner_data["front"] == 2 and corner_data["back"] == 0:
		is_mini = true
		is_t_spin = true  # Mini is still a T-spin type
	
	game.t_spin_detected.emit(is_t_spin, is_mini)

# Check if the parent body is a T-piece
func _is_t_piece() -> bool:
	if not "shape" in parent:
		return false
	# The Tetromino.Shape enum value for T is 2 (I=0, O=1, T=2, S=3, Z=4, L=5, J=6)
	return parent.shape == 2  # Shape.T

# Evaluate the 4 diagonal corners around the T-piece pivot
func _evaluate_corners() -> Dictionary:
	var beak_dir: Vector2i = _find_beak_direction()
	var corners = _get_corner_positions()
	var front_corners = _get_front_corners(beak_dir)
	
	var space_state = parent.get_world_2d().direct_space_state
	var front_count: int = 0
	var back_count: int = 0
	
	for corner_offset in corners:
		var world_pos: Vector2 = parent.global_position + Vector2(corner_offset.x * step_size, corner_offset.y * step_size)
		var occupied: bool = _is_position_occupied(space_state, world_pos) or _is_out_of_bounds(world_pos)
		
		if occupied:
			if corner_offset in front_corners:
				front_count += 1
			else:
				back_count += 1
	
	return { "front": front_count, "back": back_count }

# Find the beak direction from current offsets.
# The beak is the one cell that doesn't share a row with 3 others (or col).
func _find_beak_direction() -> Vector2i:
	if not "current_offsets" in parent:
		return Vector2i.ZERO
	
	var offsets: Array = parent.current_offsets
	
	# Group by Y
	var by_y: Dictionary = {}
	for o in offsets:
		if not by_y.has(o.y):
			by_y[o.y] = []
		by_y[o.y].append(o)
	for y_key in by_y:
		if by_y[y_key].size() >= 3:
			for o in offsets:
				if o.y != y_key:
					return Vector2i(o.x, o.y)
	
	# Group by X
	var by_x: Dictionary = {}
	for o in offsets:
		if not by_x.has(o.x):
			by_x[o.x] = []
		by_x[o.x].append(o)
	for x_key in by_x:
		if by_x[x_key].size() >= 3:
			for o in offsets:
				if o.x != x_key:
					return Vector2i(o.x, o.y)
	
	return Vector2i.ZERO

# All 4 diagonal corner offsets relative to pivot
func _get_corner_positions() -> Array[Vector2i]:
	return [
		Vector2i(-1, -1),  # NW
		Vector2i(1, -1),   # NE
		Vector2i(-1, 1),   # SW
		Vector2i(1, 1),    # SE
	]

# Get the two "front" corner offsets based on beak direction
func _get_front_corners(beak_dir: Vector2i) -> Array[Vector2i]:
	match beak_dir:
		Vector2i(0, -1):  # Facing UP
			return [Vector2i(-1, -1), Vector2i(1, -1)]
		Vector2i(1, 0):   # Facing RIGHT
			return [Vector2i(1, -1), Vector2i(1, 1)]
		Vector2i(0, 1):   # Facing DOWN
			return [Vector2i(-1, 1), Vector2i(1, 1)]
		Vector2i(-1, 0):  # Facing LEFT
			return [Vector2i(-1, -1), Vector2i(-1, 1)]
		_:
			return []

# Check if a world position is occupied by a physics body
func _is_position_occupied(space_state: PhysicsDirectSpaceState2D, world_pos: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, world_pos)
	query.collision_mask = parent.collision_mask
	query.exclude = [parent.get_rid()]
	return space_state.intersect_shape(query).size() > 0

# Check if a world position is outside the playfield bounds
func _is_out_of_bounds(world_pos: Vector2) -> bool:
	if not "x_min" in parent or not "y_min" in parent:
		return false
	return world_pos.x < parent.x_min or world_pos.x > parent.x_max or \
		world_pos.y < parent.y_min or world_pos.y > parent.y_max