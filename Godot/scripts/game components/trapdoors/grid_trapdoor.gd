# GridTrapdoor
# Spawns entities in a centered 2D grid with two modes: data-driven or math-driven
# Mode A uses CDGridLayout resources, Mode B uses CDGridEquation with random skip logic

class_name GridTrapdoor extends CDStageTrapdoor

# --- exports ---

# data-driven grid layout (Mode A) — maps cells to scenes
@export var layout: CDGridLayout = null
# single scene for all cells (Mode B)
@export var spawn_scene: PackedScene = null
# math-driven grid equation (Mode B) — columns, rows, skip chance
@export var equation: CDGridEquation = null
# size of each grid cell
@export var cell_size: Vector2 = Vector2(16, 16)
# gap between cells
@export var cell_spacing: Vector2 = Vector2(2, 2)

# --- state ---

# set of flat indices to skip (Mode B only)
var _skip_set: Dictionary = {}
# grid dimensions from layout or equation
var _grid_columns: int = 0
var _grid_rows: int = 0

# --- trigger override ---

# dispatch to Mode A or Mode B based on configured resources
func _on_trigger(wave_number: int = 0) -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return

	_current_wave = wave_number

	_spawn_queue.clear()

	# Mode A: data-driven layout takes priority
	if layout != null:
		if spawn_scene != null and equation != null:
			push_warning("GridTrapdoor '%s': both layout (Mode A) and scene+equation (Mode B) configured. Mode A takes priority." % name)
		_populate_queue_mode_a()
	# Mode B: math-driven with skip logic
	elif spawn_scene != null and equation != null:
		_populate_queue_mode_b()
	else:
		push_error("GridTrapdoor '%s': no valid configuration. set layout (mode A) or spawn_scene + equation (mode B)." % name)
		return

	_spawn_timer = 0.0
	set_physics_process(true)

# --- queue population ---

# Mode A: queue all non-empty cells from the layout resource
func _populate_queue_mode_a() -> void:
	var total_cells := layout.rows.size() * layout.columns
	for i in total_cells:
		if layout.get_cell(i) != null:
			_spawn_queue.append(i)
	_grid_columns = layout.columns
	_grid_rows = layout.rows.size()

# Mode B: apply random skip chance with per-row minimum enforcement
func _populate_queue_mode_b() -> void:
	_skip_set.clear()
	_grid_columns = equation.columns
	_grid_rows = equation.rows

	var total_cells := _grid_columns * _grid_rows

	# first pass: random skips based on skip_chance
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
		# add random skips until minimum is met
		while skips_in_row < equation.min_skips_per_row:
			var col := randi_range(row_start, row_end - 1)
			if not _skip_set.has(col):
				_skip_set[col] = true
				skips_in_row += 1

	# queue non-skipped cells for spawning
	for i in total_cells:
		if not _skip_set.has(i):
			_spawn_queue.append(i)

# --- virtual overrides ---

# convert flat index to centered grid world position
func _get_spawn_position(index: int, _total: int) -> Vector2:
	var col := index % _grid_columns
	@warning_ignore("integer_division")
	var row := index / _grid_columns
	var step_x := cell_size.x + cell_spacing.x
	var step_y := cell_size.y + cell_spacing.y
	var grid_width := _grid_columns * step_x - cell_spacing.x
	var grid_height := _grid_rows * step_y - cell_spacing.y
	# center the grid on the trapdoor's global position
	return global_position + Vector2(
		col * step_x - grid_width * 0.5,
		row * step_y - grid_height * 0.5,
	)

# return scene from layout (Mode A) or single scene (Mode B)
func _get_spawn_scene(index: int, _total: int) -> PackedScene:
	if layout != null:
		return layout.get_cell(index)
	return spawn_scene
