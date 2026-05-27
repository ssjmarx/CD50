## spawns entities in a 2D grid using data or math
class_name GridTrapdoor extends CDStageTrapdoor

@export var layout: CDGridLayout = null
@export var spawn_scene: PackedScene = null
@export var equation: CDGridEquation = null
@export var cell_size: Vector2 = Vector2(16, 16)
@export var cell_spacing: Vector2 = Vector2(2, 2)

var _skip_set: Dictionary = {}  # {flat_index: true}
var _grid_columns: int = 0
var _grid_rows: int = 0

func _on_trigger(wave_number: int = 0) -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return

	_current_wave = wave_number

	_spawn_queue.clear()

	if layout != null:
		if spawn_scene != null and equation != null:
			push_warning("GridTrapdoor '%s': both layout (Mode A) and scene+equation (Mode B) configured. Mode A takes priority." % name)
		_populate_queue_mode_a()
	elif spawn_scene != null and equation != null:
		_populate_queue_mode_b()
	else:
		push_error("GridTrapdoor '%s': no valid configuration. set layout (mode A) or spawn_scene + equation (mode B)." % name)
		return

	_spawn_timer = 0.0
	set_physics_process(true)

## data driven mode
func _populate_queue_mode_a() -> void:
	var total_cells := layout.rows.size() * layout.columns
	for i in total_cells:
		if layout.get_cell(i) != null:
			_spawn_queue.append(i)
	_grid_columns = layout.columns
	_grid_rows = layout.rows.size()

## math driven mode
func _populate_queue_mode_b() -> void:
	_skip_set.clear()
	_grid_columns = equation.columns
	_grid_rows = equation.rows

	var total_cells := _grid_columns * _grid_rows

	# first pass: random skips
	for i in total_cells:
		if randf() < equation.skip_chance:
			_skip_set[i] = true

	# second pass: enforce min_skips_per_row
	for row in _grid_rows:
		var row_start := row * _grid_columns
		var row_end := row_start + _grid_columns
		var skips_in_row := 0
		for i in range(row_start, row_end):
			if _skip_set.has(i):
				skips_in_row += 1
		while skips_in_row < equation.min_skips_per_row:
			var col := randi_range(row_start, row_end - 1)
			if not _skip_set.has(col):
				_skip_set[col] = true
				skips_in_row += 1

	# queue non-skipped cells
	for i in total_cells:
		if not _skip_set.has(i):
			_spawn_queue.append(i)

func _get_spawn_position(index: int, _total: int) -> Vector2:
	var col := index % _grid_columns
	@warning_ignore("integer_division")
	var row := index / _grid_columns
	var step_x := cell_size.x + cell_spacing.x
	var step_y := cell_size.y + cell_spacing.y
	var grid_width := _grid_columns * step_x - cell_spacing.x
	var grid_height := _grid_rows * step_y - cell_spacing.y
	return global_position + Vector2(
		col * step_x - grid_width * 0.5,
		row * step_y - grid_height * 0.5,
	)

func _get_spawn_scene(index: int, _total: int) -> PackedScene:
	if layout != null:
		return layout.get_cell(index)
	return spawn_scene
