extends UniversalComponent2D

@export var rows: int = 18
@export var columns: int = 32
@export var cell_size: Vector2 = Vector2(20, 20)

var _occupancy: Array = []

func _ready():
	_init_grid()

func _draw() -> void:
	for r in range(rows + 1):
		draw_line(
			Vector2(0, r * cell_size.y),
			Vector2(columns * cell_size.x, r * cell_size.y),
			Color.GRAY, 1.0
		)
	for c in range(columns + 1):
		draw_line(
			Vector2(c * cell_size.x, 0),
			Vector2(c * cell_size.x, rows * cell_size.y),
			Color.GRAY, 1.0
		)

func _init_grid() -> void:
	_occupancy.clear()
	for r in range(rows):
		var row: Array = []
		row.resize(columns)
		row.fill(null)
		_occupancy.append(row)

func grid_to_world(row: int, col: int) -> Vector2:
	return global_position + Vector2(col * cell_size.x, row * cell_size.y) + (cell_size * 0.5)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int((world_pos.y - global_position.y) / cell_size.y), int((world_pos.x - global_position.x) / cell_size.x))

func is_valid_cell(row: int, col: int) -> bool:
	return row >= 0 and row < rows and col >= 0 and col < columns

func is_occupied(row: int, col: int) -> bool:
	return is_valid_cell(row, col) and _occupancy[row][col] != null

func register_cell(row: int, col: int, data = null) -> void:
	if is_valid_cell(row, col):
		_occupancy[row][col] = data

func unregister_cell(row: int, col: int) -> void:
	if is_valid_cell(row, col):
		_occupancy[row][col] = null

func get_cell_data(row: int, col: int) -> Variant:
	return _occupancy[row][col]

func get_row(row: int) -> Array:
	return _occupancy[row]

func get_column(col: int) -> Array:
	var result: Array = []
	for r in range(rows):
		result.append(_occupancy[r][col])
	return result

func is_row_full(row: int) -> bool:
	for col in range(columns):
		if _occupancy[row][col] == null:
			return false
	return true

func is_column_full(col: int) -> bool:
	for row in range(rows):
		if _occupancy[row][col] == null:
			return false
	return true

func clear_row(row: int) -> void:
	if row >= 0 and row < rows:
		_occupancy[row].fill(null)

func clear_column(col: int) -> void:
	if col >= 0 and col < columns:
		for r in range(rows):
			_occupancy[r][col] = null

func shift_rows_down(from_row: int, count: int = 1) -> void:
	for r in range(from_row - 1, -1, -1):
		var target_row = r + count
		if target_row < rows:
			_occupancy[target_row] = _occupancy[r]
	
	for r in range(count):
		var new_row: Array = []
		new_row.resize(columns)
		new_row.fill(null)
		_occupancy[r] = new_row

func clear_all() -> void:
	_init_grid()
