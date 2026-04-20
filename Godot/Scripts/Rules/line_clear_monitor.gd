extends UniversalComponent

@export var lines_per_level: int = 10
@export var score_table: Array[int] = [0, 100, 300, 500, 800]
@export var clear_delay: float = 0.3

signal lines_cleared(count: int, row_indices: Array[int])
signal level_changed(new_level: int)
signal score_gained(points: int)

var _grid: Node2D
var _spawner: Node
var _total_lines_cleared: int = 0
var _level: int = 1
var _is_clearing: bool = false

func _ready() -> void:
	_grid = get_tree().get_first_node_in_group("grid")
	# Find spawner — could be by group, path, or export
	_spawner = get_tree().get_first_node_in_group("tetromino_spawner")
	if _spawner:
		_spawner.piece_did_lock.connect(_on_piece_locked)

func _on_piece_locked() -> void:
	if _is_clearing:
		return
	_check_and_clear()

func _check_and_clear() -> void:
	var full_rows = _find_full_rows()
	
	if full_rows.is_empty():
		return
	
	_is_clearing = true
	
	# Emit signals
	var count = full_rows.size()
	lines_cleared.emit(count, full_rows)
	
	var points = score_table[mini(count, score_table.size() - 1)] * _level
	score_gained.emit(points)
	
	# Update level
	_total_lines_cleared += count
	var new_level = 1 + (_total_lines_cleared / lines_per_level)
	if new_level != _level:
		_level = new_level
		level_changed.emit(_level)
	
	# Clear animation pause
	await get_tree().create_timer(clear_delay).timeout
	
	# Remove bodies in cleared rows
	_clear_rows(full_rows)
	
	# Shift everything above down
	_collapse_rows(full_rows)
	
	_is_clearing = false

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

func _clear_rows(rows: Array[int]) -> void:
	for row in rows:
		var cols = _grid.get_col_count()
		for col in range(cols):
			var body = _grid.get_body_at(row, col)
			if body and is_instance_valid(body):
				body.queue_free()
			_grid.unregister_cell(row, col)

func _collapse_rows(cleared_rows: Array[int]) -> void:
	# Sort cleared rows descending (bottom to top) for correct shifting
	var sorted = cleared_rows.duplicate()
	sorted.sort()
	sorted.reverse()
	
	# For each cleared row, shift everything above it down by 1
	for cleared_row in sorted:
		_shift_rows_above_down(cleared_row)

func _shift_rows_above_down(from_row: int) -> void:
	var cols = _grid.get_col_count()
	var top_row = 0
	
	for row in range(from_row - 1, top_row - 1, -1):
		for col in range(cols):
			if _grid.is_occupied(row, col):
				var body = _grid.get_body_at(row, col)
				
				# Update grid data
				_grid.unregister_cell(row, col)
				_grid.register_cell(row + 1, col, body)
				
				# Move the actual body
				if body and is_instance_valid(body):
					body.global_position = _grid.grid_to_world(row + 1, col)
