# Ghost piece component. Projects the active piece downward to show its landing
# position as a transparent outline. Updates on move and rotation signals.

extends UniversalComponent

# Grid spacing for projection. Must match grid_movement.step_size.
@export var step_size: float = 18.0

# Physics check size (slightly < tile_size to avoid false positives)
@export var cell_size: float = 17.9

func _ready() -> void:
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	# Listen to sibling movement and rotation signals
	for child in parent.get_children():
		if child == self:
			continue
		if child.has_signal("moved"):
			child.moved.connect(_update_ghost)
		if child.has_signal("rotated"):
			child.rotated.connect(_update_ghost)
	# Also listen for gravity fell signal
	for child in parent.get_children():
		if child == self:
			continue
		if child.has_signal("fell"):
			child.fell.connect(_update_ghost)
	# Initial ghost calculation
	_update_ghost()

func _update_ghost() -> void:
	var ghost = _project_landing()
	parent.ghost_offsets = ghost
	parent.queue_redraw()

# Project the piece straight down until blocked
func _project_landing() -> Array[Vector2i]:
	var displacement = 0
	while _can_drop_one_more(displacement):
		displacement += 1
	# Convert landing position back to offsets relative to parent
	var offsets: Array[Vector2i] = []
	if "current_offsets" in parent:
		for offset in parent.current_offsets:
			offsets.append(Vector2i(offset.x, offset.y + displacement))
	return offsets

# Test if piece can exist one step further down from current displacement
func _can_drop_one_more(current_displacement: int) -> bool:
	if not ("current_offsets" in parent and parent.current_offsets.size() > 0):
		return false
	
	var space_state = parent.get_world_2d().direct_space_state
	var test_y = parent.global_position.y + (current_displacement + 1) * step_size
	
	for offset in parent.current_offsets:
		var cell_pos = Vector2(
			parent.global_position.x + offset.x * step_size,
			test_y + offset.y * step_size
		)
		# Bounds check
		if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
			return false
		if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
			return false
		# Physics occupancy check
		if _is_cell_occupied(space_state, cell_pos):
			return false
	return true

# Check if a cell position is occupied by another physics body
func _is_cell_occupied(space_state: PhysicsDirectSpaceState2D, cell_pos: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, cell_pos)
	query.collision_mask = parent.collision_mask
	query.exclude = [parent.get_rid()]
	return space_state.intersect_shape(query).size() > 0