# Line clear monitor for Tetris. Detects full rows when a piece locks,
# emits score/level signals, then clears and collapses rows with a delay.

extends UniversalComponent

# Scoring and timing configuration
@export var lines_per_level: int = 10
@export var score_table: Array[int] = [0, 100, 300, 500, 800]
@export var clear_delay: float = 0.3

# Emitted when rows are cleared with count and row indices
signal lines_cleared(count: int, row_indices: Array[int])
# Emitted when the level increases
signal level_changed(new_level: int)
# Emitted with the score awarded for a clear
signal score_gained(points: int)

# Runtime state
var _grid: Node2D
var _spawner: Node
var _total_lines_cleared: int = 0
var _level: int = 1
var _is_clearing: bool = false

# Find grid and spawner, connect to the spawner's lock signal
func _ready() -> void:
	_grid = get_tree().get_first_node_in_group("grid")
	_spawner = get_tree().get_first_node_in_group("tetromino_spawner")
	if _spawner:
		_spawner.piece_did_lock.connect(_on_piece_locked)

# Trigger a clear check when a piece locks (skip if already clearing)
func _on_piece_locked() -> void:
	if _is_clearing:
		return
	_check_and_clear()

# --- Clear Cycle ---

# Find full rows, emit signals, pause for animation, then clear and collapse
func _check_and_clear() -> void:
	var full_rows = _find_full_rows()
	
	if full_rows.is_empty():
		return
	
	_is_clearing = true
	
	# Emit scoring signals
	var count = full_rows.size()
	lines_cleared.emit(count, full_rows)
	
	var points = score_table[mini(count, score_table.size() - 1)] * _level
	score_gained.emit(points)
	
	# Track level progression
	_total_lines_cleared += count
	@warning_ignore("integer_division")
	var new_level = 1 + (_total_lines_cleared / lines_per_level)
	if new_level != _level:
		_level = new_level
		level_changed.emit(_level)
	
	# Pause for clear animation
	await get_tree().create_timer(clear_delay).timeout
	
	_clear_rows(full_rows)
	_collapse_rows(full_rows)
	
	_is_clearing = false

# --- Row Detection ---

# Scan the grid and return an array of fully-occupied row indices
func _find_full_rows() -> Array[int]:
	var full: Array[int] = []
	var rows = _grid.get_row_count()
	var cols = _grid.get_col_count()
	
	for row in range(rows):
		var is_full = true
		for col in range(cols):
			if not _grid.is_occupied(row, col):
				is_full = false
				break
		if is_full:
			full.append(row)
	
	return full

# --- Row Mutation ---

# Free bodies and unregister cells in the given rows
func _clear_rows(rows: Array[int]) -> void:
	for row in rows:
		var cols = _grid.get_col_count()
		for col in range(cols):
			var body = _grid.get_body_at(row, col)
			if body and is_instance_valid(body):
				body.queue_free()
			_grid.unregister_cell(row, col)

# Shift all rows above each cleared row downward by one
func _collapse_rows(cleared_rows: Array[int]) -> void:
	# Sort descending (bottom to top) for correct shifting
	var sorted = cleared_rows.duplicate()
	sorted.sort()
	sorted.reverse()
	
	for cleared_row in sorted:
		_shift_rows_above_down(cleared_row)

# Move grid data and body positions from [from_row-1 .. 0] down one row
func _shift_rows_above_down(from_row: int) -> void:
	var cols = _grid.get_col_count()
	var top_row = 0
	
	for row in range(from_row - 1, top_row - 1, -1):
		for col in range(cols):
			if _grid.is_occupied(row, col):
				var body = _grid.get_body_at(row, col)
				
				# Update grid occupancy data
				_grid.unregister_cell(row, col)
				_grid.register_cell(row + 1, col, body)
				
				# Move the visual body to the new grid position
				if body and is_instance_valid(body):
					body.global_position = _grid.grid_to_world(row + 1, col)
