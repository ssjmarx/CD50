 # Line clear monitor. Physics-based line detection using world-space queries.
# Zero grid data structure dependency — scans collision shapes directly.

extends UniversalComponent2D

# Playfield geometry
@export var playfield_origin: Vector2 = Vector2.ZERO     # top-left corner in world space
@export var cell_size: Vector2 = Vector2(18, 18)          # must match tetromino tile_size
@export var rows: int = 20
@export var columns: int = 10

# Detection configuration
@export var target_group: String = "settled_pieces"               # which group counts as "filled"
@export var listen_signal: String = "piece_settled"         # signal name to listen for on game

# Scoring and timing
@export var clear_delay: float = 0.3                        # pause for clear animation
@export var use_health_kill: bool = false                   # kill via Health component instead of queue_free
@export var sequential_kill_delay: float = 0.01            # delay between sequential kills in a line
@export var enable_line_flash: bool = true                  # flash cleared rows white before clearing
@export var enable_smooth_collapse: bool = true             # smooth collapse animation
@export var collapse_duration: float = 0.1                  # seconds for collapse tween
@export var lines_per_level: int = 10
@export var score_table: Array[int] = [0, 100, 300, 500, 800]
@export var level_multiplier_increment: int = 1             # added to game.current_multiplier each level

# Enhanced scoring toggles
@export var enable_combo: bool = false
@export var enable_back_to_back: bool = false
@export var enable_t_spin_scoring: bool = false

# T-spin scoring tables (indexed by lines cleared: 0, 1, 2, 3)
@export var t_spin_score_table: Array[int] = [400, 800, 1200, 1600]
@export var t_spin_mini_score_table: Array[int] = [100, 300, 600, 900]

# Combo bonus per consecutive clear
@export var combo_bonus: int = 50

# Back-to-back multiplier (applied to difficult clears: Block Drop, T-spin)
@export var b2b_multiplier: float = 1.5

# Score type for routing — uses standard enum like all other scoring components
@export var score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS

# Emitted when rows are cleared with count and row indices
signal lines_cleared(count: int, row_indices: Array[int])
# Emitted when the level increases
signal level_changed(new_level: int)
# Emitted with the score awarded for a clear
signal score_gained(points: int)
# Emitted when a back-to-back bonus is applied on a difficult clear
signal back_to_back

# Runtime state
var _total_lines_cleared: int = 0
var _level: int = 1
var _is_clearing: bool = false
var _combo_count: int = -1          # -1 = no active combo; incremented each consecutive clear
var _is_b2b_eligible: bool = false  # True after a "difficult" clear (Block Drop or T-spin)
var _last_t_spin: bool = false
var _last_t_spin_mini: bool = false

# Connect to the configured signal on the game node
func _ready() -> void:
	if game and game.has_signal(listen_signal):
		game.connect(listen_signal, _on_piece_settled)
	if game and game.has_signal("t_spin_detected") and enable_t_spin_scoring:
		game.t_spin_detected.connect(_on_t_spin_detected)

# Store T-spin result from detector, used during next scoring
func _on_t_spin_detected(is_t_spin: bool, is_mini: bool) -> void:
	_last_t_spin = is_t_spin
	_last_t_spin_mini = is_mini

# Trigger a clear check when a piece settles (skip if already clearing)
func _on_piece_settled() -> void:
	if _is_clearing:
		return
	_check_and_clear()

# --- Clear Cycle ---

# Find full rows, emit signals, pause for animation, then clear and collapse
func _check_and_clear() -> void:
	var full_rows = _find_full_rows()
	
	# No lines cleared — reset combo, reset T-spin state
	if full_rows.is_empty():
		_combo_count = -1
		_last_t_spin = false
		_last_t_spin_mini = false
		return
	
	_is_clearing = true
	
	var count = full_rows.size()
	lines_cleared.emit(count, full_rows)
	
	# --- Calculate score ---
	var points: int = _calculate_score(count)
	
	# Apply B2B multiplier
	if enable_back_to_back and _is_b2b_eligible and _is_difficult_clear(count):
		points = int(points * b2b_multiplier)
		back_to_back.emit()
	
	# Add combo bonus
	if enable_combo and _combo_count > 0:
		points += _combo_count * combo_bonus
	
	# Emit and add score
	score_gained.emit(points)
	_apply_score(points)
	
	# --- Update state ---
	# Combo: increment on every consecutive clear
	if enable_combo:
		_combo_count += 1
	
	# B2B eligibility: set if this was a difficult clear
	if enable_back_to_back:
		_is_b2b_eligible = _is_difficult_clear(count)
	
	# Track level progression — increment UGS multiplier on level up
	_total_lines_cleared += count
	@warning_ignore("integer_division")
	var new_level = 1 + (_total_lines_cleared / lines_per_level)
	if new_level != _level:
		var levels_gained = new_level - _level
		_level = new_level
		if game:
			game.current_multiplier += level_multiplier_increment * levels_gained
		level_changed.emit(_level)
	
	# Reset T-spin state after scoring
	_last_t_spin = false
	_last_t_spin_mini = false
	
	# Kill rows: either via Health component (sequential death effects) or direct free
	if use_health_kill:
		await _kill_rows_sequential(full_rows)
	else:
		# Flash cleared rows white during the clear delay
		if enable_line_flash:
			_flash_rows(full_rows)
		
		# Pause for clear animation (includes flash time)
		await get_tree().create_timer(clear_delay).timeout
		
		_clear_rows(full_rows)
	
	_collapse_rows(full_rows)
	
	_is_clearing = false

# Calculate base score for a line clear, considering T-spin
func _calculate_score(lines: int) -> int:
	var idx = mini(lines, score_table.size() - 1)
	
	# T-spin scoring takes priority
	if enable_t_spin_scoring and _last_t_spin:
		var t_idx = mini(lines, t_spin_score_table.size() - 1)
		if _last_t_spin_mini:
			return t_spin_mini_score_table[mini(lines, t_spin_mini_score_table.size() - 1)]
		else:
			return t_spin_score_table[t_idx]
	
	return score_table[idx]

# A "difficult" clear qualifies for back-to-back bonus (Block Drop or any T-spin)
func _is_difficult_clear(lines: int) -> bool:
	if lines >= 4:
		return true
	if enable_t_spin_scoring and _last_t_spin:
		return true
	return false

# Route score to the correct UGS method based on score_type
func _apply_score(points: int) -> void:
	if not game:
		return
	match score_type:
		CommonEnums.ScoreType.P1_SCORE:
			game.add_p1_score(points)
		CommonEnums.ScoreType.P2_SCORE:
			game.add_p2_score(points)
		CommonEnums.ScoreType.POINTS:
			game.add_score(points)
		CommonEnums.ScoreType.MULTIPLIER:
			game.add_multiplier(float(points))

# --- Row Detection (Physics-Based) ---

# Scan playfield rows using physics point queries
func _find_full_rows() -> Array[int]:
	var full: Array[int] = []
	var space_state = get_world_2d().direct_space_state
	
	for row in range(rows):
		var y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2.0
		var is_full = true
		
		for col in range(columns):
			var x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2.0
			if not _is_cell_filled(space_state, Vector2(x_pos, y_pos)):
				is_full = false
				break
		
		if is_full:
			full.append(row)
	
	return full

# Check if a cell position is occupied by a body in the target group
func _is_cell_filled(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> bool:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	# Use a small area query to handle slight misalignments
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var body = result["collider"]
		if body and body.is_in_group(target_group):
			return true
	
	return false

# --- Row Mutation ---

# Kill bodies in cleared rows sequentially via Health component (triggers death effects).
# Falls back to queue_free() if no Health component is found.
func _kill_rows_sequential(row_indices: Array[int]) -> void:
	var space_state = get_world_2d().direct_space_state
	var first_kill = true
	
	for row in row_indices:
		var y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2.0
		
		for col in range(columns):
			var x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2.0
			var body = _get_body_at(space_state, Vector2(x_pos, y_pos))
			
			if body and is_instance_valid(body):
				# Small delay between kills for sequential cascade effect
				if not first_kill:
					await get_tree().create_timer(sequential_kill_delay).timeout
				first_kill = false
				
				# Try to kill via Health component (triggers death_effect)
				var health_comp = _find_health_component(body)
				if health_comp:
					health_comp.reduce_health(health_comp.current_health)
				else:
					body.queue_free()

# Find a Health component on the given body
func _find_health_component(body: Node) -> Node:
	for child in body.get_children():
		if child.has_signal("zero_health"):
			return child
	return null

# Get a single body in the target group at the given position
func _get_body_at(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> Node2D:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var body = result["collider"]
		if body and body.is_in_group(target_group):
			return body
	return null

# Free all bodies in the target group that occupy the given rows
func _clear_rows(row_indices: Array[int]) -> void:
	var space_state = get_world_2d().direct_space_state
	
	for row in row_indices:
		var y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2.0
		
		for col in range(columns):
			var x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2.0
			_free_body_at(space_state, Vector2(x_pos, y_pos))

# Find and free a body in the target group at the given position
func _free_body_at(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> void:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	
	for result in results:
		var body = result["collider"]
		if body and body.is_in_group(target_group) and is_instance_valid(body):
			body.queue_free()
			return  # Only one body per cell

# Flash the bodies in cleared rows white 2-3 times during the clear delay
func _flash_rows(row_indices: Array[int]) -> void:
	var bodies = _get_bodies_in_rows(row_indices)
	if bodies.is_empty():
		return
	
	var flash_count = 3
	var flash_interval = clear_delay / (flash_count * 2)
	
	for i in flash_count:
		# Flash white
		for body in bodies:
			if is_instance_valid(body):
				body.modulate = Color.WHITE
		await get_tree().create_timer(flash_interval).timeout
		# Flash back to visible color
		for body in bodies:
			if is_instance_valid(body):
				body.modulate = Color(1, 1, 1, 0.5)
		await get_tree().create_timer(flash_interval).timeout
	
	# Restore full opacity
	for body in bodies:
		if is_instance_valid(body):
			body.modulate = Color.WHITE

# Find all bodies in the target group that occupy the given rows
func _get_bodies_in_rows(row_indices: Array[int]) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var space_state = get_world_2d().direct_space_state
	
	for row in row_indices:
		var y_pos = playfield_origin.y + row * cell_size.y + cell_size.y / 2.0
		for col in range(columns):
			var x_pos = playfield_origin.x + col * cell_size.x + cell_size.x / 2.0
			var query = PhysicsPointQueryParameters2D.new()
			query.position = Vector2(x_pos, y_pos)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hits = space_state.intersect_point(query)
			for hit in hits:
				var body = hit["collider"]
				if body and body.is_in_group(target_group) and body not in result:
					result.append(body)
	
	return result

# Shift all remaining settled bodies downward by the number of cleared rows below them.
# Uses smooth tweening when enable_smooth_collapse is true.
func _collapse_rows(cleared_rows: Array[int]) -> void:
	var bodies = get_tree().get_nodes_in_group(target_group)
	var tweens: Array[Tween] = []
	
	for body in bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		
		var body_row = _world_to_row(body.global_position.y)
		if body_row < 0:
			continue
		
		# Skip bodies sitting at cleared rows (being freed)
		if body_row in cleared_rows:
			continue
		
		# Count how many cleared rows are BELOW this body
		var shift_count := 0
		for cleared_row in cleared_rows:
			if cleared_row > body_row:
				shift_count += 1
		
		if shift_count > 0:
			var target_y = body.global_position.y + shift_count * cell_size.y
			if enable_smooth_collapse:
				var t = create_tween()
				t.tween_property(body, "global_position:y", target_y, collapse_duration).set_ease(Tween.EASE_IN)
				tweens.append(t)
			else:
				body.global_position.y = target_y
	
	# Wait for all collapse tweens to finish
	if tweens.size() > 0:
		await tweens[0].finished

# Convert a world y-position to a row index
func _world_to_row(y_pos: float) -> int:
	return int((y_pos - playfield_origin.y) / cell_size.y)
