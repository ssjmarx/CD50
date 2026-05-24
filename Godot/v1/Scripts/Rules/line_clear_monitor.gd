# Line clear monitor. Physics-based line detection using world-space queries.
# Zero grid data structure dependency — scans collision shapes directly.
# Captures body references during detection so subsequent kill/clear/flash
# operations are immune to swarm movement during await delays.

extends UniversalComponent2D

# Playfield geometry
@export var playfield_origin: Vector2 = Vector2.ZERO     # top-left corner in world space
@export var cell_size: Vector2 = Vector2(18, 18)          # must match tetromino tile_size
@export var rows: int = 20
@export var columns: int = 10

# Detection configuration
@export var target_group: String = "settled_pieces"               # which group counts as "filled"
@export var target_groups: Array[String] = []                     # multi-group: if non-empty, overrides target_group
@export var listen_signal: String = "piece_settled"         # signal name to listen for on game

# Swarm tracking — listen to SwarmController's swarm_move signal to shift the scan grid horizontally
@export var swarm_step_size: float = 18.0  # must match invaders' GridMovement step_size

# Playfield markers — draw a checkerboard overlay showing the detection area
@export var show_playfield_markers: bool = false
@export var marker_color: Color = Color(1, 1, 1, 0.1)

# Reset — listen for a game signal to reset swarm offset (e.g. when a wave is cleared)
@export var reset_on_signal: String = ""
@export var reset_signal_group: String = ""

# Scoring and timing
@export var clear_delay: float = 0.3                        # pause for clear animation
@export var use_health_kill: bool = false                   # kill via Health component instead of queue_free
@export var sequential_kill_delay: float = 0.01            # delay between sequential kills in a line
@export var enable_line_flash: bool = true                  # flash cleared rows white before clearing
@export var enable_smooth_collapse: bool = true             # smooth collapse animation
@export var collapse_direction: Vector2 = Vector2(0, 1)     # direction bodies shift after a clear (down=default, up=reversed)
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
var _swarm_controller: Node = null  # reference to SwarmController for direct offset reads
var _last_offset_x: float = 0.0    # tracked to trigger redraw when swarm offset changes

# Connect to the configured signal on the game node
func _ready() -> void:
	if game and game.has_signal(listen_signal):
		game.connect(listen_signal, _on_piece_settled)
	if game and game.has_signal("t_spin_detected") and enable_t_spin_scoring:
		game.t_spin_detected.connect(_on_t_spin_detected)
	_connect_swarm_controller()

# Find and store reference to SwarmController for direct offset reads
func _connect_swarm_controller() -> void:
	if not game:
		return
	for child in game.get_children():
		if "swarm_offset_x" in child:
			_swarm_controller = child
			break

# Redraw playfield markers when the swarm offset changes
func _physics_process(_delta: float) -> void:
	if not show_playfield_markers:
		return
	var current_offset: float = 0.0
	if _swarm_controller and is_instance_valid(_swarm_controller):
		current_offset = _swarm_controller.swarm_offset_x
	if current_offset != _last_offset_x:
		_last_offset_x = current_offset
		queue_redraw()

# Draw two vertical checkerboard borders framing the detection area,
# visually identical to the Block Drop board walls.
# Each bar is 6 columns × cell_size 3 = 18px wide, flush against playfield edges.
func _draw() -> void:
	if not show_playfield_markers:
		return
	var origin = _get_effective_origin()
	var playfield_height = rows * cell_size.y
	
	# Block Drop style: 6 cols × 3px cells = 18px wide bars
	var bar_cell = 3
	var bar_cols = 6
	var bar_rows = int(playfield_height / bar_cell)
	
	# Left border: flush against left edge of playfield
	var left_x = origin.x - bar_cols * bar_cell
	for row in range(bar_rows):
		for col in range(bar_cols):
			if (row + col) % 2 == 0:
				draw_rect(Rect2(left_x + col * bar_cell, origin.y + row * bar_cell, bar_cell, bar_cell), marker_color)
	
	# Right border: flush against right edge of playfield
	var right_x = origin.x + columns * cell_size.x
	for row in range(bar_rows):
		for col in range(bar_cols):
			if (row + col) % 2 == 0:
				draw_rect(Rect2(right_x + col * bar_cell, origin.y + row * bar_cell, bar_cell, bar_cell), marker_color)

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

# Find full rows, emit signals, pause for animation, then clear and collapse.
# Body references are captured during detection so kills are immune to movement.
func _check_and_clear() -> void:
	var detected := _detect_full_rows()
	var full_rows: Array[int] = []
	for row in detected:
		full_rows.append(row)
	full_rows.sort()
	
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
	
	# Kill rows: either via Health component (sequential death effects) or direct free.
	# Uses captured body references — no physics re-query needed.
	if use_health_kill:
		await _kill_captured_rows(detected)
	else:
		# Flash captured bodies white during the clear delay
		if enable_line_flash:
			_flash_captured_rows(detected)
		
		# Pause for clear animation (includes flash time)
		await get_tree().create_timer(clear_delay).timeout
		
		_free_captured_rows(detected)
	
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

# Scan playfield rows using physics point queries.
# Returns Dictionary: {row_index: Array[Node2D]} — all bodies captured at detection time.
# Handles overlapping bodies (multiple targets per cell) by collecting all matches.
# Deduplicates across cells so the same body isn't captured twice.
func _detect_full_rows() -> Dictionary:
	var result: Dictionary = {}
	var space_state = get_world_2d().direct_space_state
	var origin = _get_effective_origin()
	
	for row in range(rows):
		var y_pos = origin.y + row * cell_size.y + cell_size.y / 2.0
		var is_full = true
		var row_bodies: Array = []
		var seen: Dictionary = {}  # dedup by instance ID
		
		for col in range(columns):
			var x_pos = origin.x + col * cell_size.x + cell_size.x / 2.0
			var cell_bodies = _get_bodies_at(space_state, Vector2(x_pos, y_pos))
			if cell_bodies.is_empty():
				is_full = false
				break
			for body in cell_bodies:
				var id = body.get_instance_id()
				if not seen.has(id):
					seen[id] = true
					row_bodies.append(body)
		
		if is_full:
			result[row] = row_bodies
	
	return result

# Get ALL bodies in any target group at the given position.
# Returns multiple results to handle overlapping entities in the same cell.
func _get_bodies_at(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> Array[Node2D]:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	var found: Array[Node2D] = []
	
	for result in results:
		var body = result["collider"]
		if body and _is_target(body):
			found.append(body)
	return found

# --- Row Mutation (uses captured body references) ---

# Kill captured bodies sequentially via Health component (triggers death effects).
# Falls back to queue_free() if no Health component is found.
func _kill_captured_rows(detected: Dictionary) -> void:
	var first_kill = true
	
	for row in detected:
		var bodies: Array = detected[row]
		for body in bodies:
			if body and is_instance_valid(body):
				# Small delay between kills for sequential cascade effect
				if not first_kill:
					await get_tree().create_timer(sequential_kill_delay).timeout
				first_kill = false
				
				# Re-check validity after await (body may have been freed by
				# concurrent systems like GroupKillOnSignal during the delay)
				if not is_instance_valid(body):
					continue
				
				# Try to kill via Health component (triggers death_effect)
				var health_comp = _find_health_component(body)
				if health_comp:
					health_comp.reduce_health(health_comp.current_health)
				else:
					body.queue_free()

# Free all captured bodies directly (no Health/death effects)
func _free_captured_rows(detected: Dictionary) -> void:
	for row in detected:
		var bodies: Array = detected[row]
		for body in bodies:
			if is_instance_valid(body) and not body.is_queued_for_deletion():
				body.queue_free()

# Flash captured bodies white 2-3 times during the clear delay
func _flash_captured_rows(detected: Dictionary) -> void:
	# Flatten all captured bodies (deduplicated)
	var all_bodies: Array = []
	for row in detected:
		for body in detected[row]:
			if body not in all_bodies:
				all_bodies.append(body)
	
	if all_bodies.is_empty():
		return
	
	var flash_count = 3
	var flash_interval = clear_delay / (flash_count * 2)
	
	for i in flash_count:
		# Flash white
		for body in all_bodies:
			if is_instance_valid(body):
				body.modulate = Color.WHITE
		await get_tree().create_timer(flash_interval).timeout
		# Flash back to visible color
		for body in all_bodies:
			if is_instance_valid(body):
				body.modulate = Color(1, 1, 1, 0.5)
		await get_tree().create_timer(flash_interval).timeout
	
	# Restore full opacity
	for body in all_bodies:
		if is_instance_valid(body):
			body.modulate = Color.WHITE

# Find a Health component on the given body
func _find_health_component(body: Node) -> Node:
	for child in body.get_children():
		if child.has_signal("zero_health"):
			return child
	return null

# --- Collapse ---

# Shift all remaining settled bodies downward by the number of cleared rows below them.
# Uses smooth tweening when enable_smooth_collapse is true.
func _collapse_rows(cleared_rows: Array[int]) -> void:
	var bodies = _get_all_target_bodies()
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
		
		# Count how many cleared rows are in the collapse direction
		var shift_count := 0
		var is_reversed = collapse_direction.y < 0
		for cleared_row in cleared_rows:
			if is_reversed:
				if cleared_row < body_row:
					shift_count += 1
			else:
				if cleared_row > body_row:
					shift_count += 1
		
		if shift_count > 0:
			var target_y = body.global_position.y + shift_count * cell_size.y * signf(collapse_direction.y)
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
	var origin = _get_effective_origin()
	return int((y_pos - origin.y) / cell_size.y)

# --- Multi-Group & Swarm Tracking Helpers ---

# Check if a body belongs to any target group
func _is_target(body: Node) -> bool:
	if target_groups.is_empty():
		return body.is_in_group(target_group)
	for group in target_groups:
		if body.is_in_group(group):
			return true
	return false

# Gather all bodies from all target groups
func _get_all_target_bodies() -> Array[Node]:
	if target_groups.is_empty():
		return get_tree().get_nodes_in_group(target_group)
	var all: Array[Node] = []
	for group in target_groups:
		all.append_array(get_tree().get_nodes_in_group(group))
	return all

# Get the effective playfield origin, offset by accumulated swarm horizontal movement.
# Reads directly from SwarmController when available (source of truth), avoiding
# signal-based tracking that can desync between wave resets.
func _get_effective_origin() -> Vector2:
	var offset_x: float = 0.0
	if _swarm_controller and is_instance_valid(_swarm_controller):
		offset_x = _swarm_controller.swarm_offset_x
	return Vector2(playfield_origin.x + offset_x, playfield_origin.y)