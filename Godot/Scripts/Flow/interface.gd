# Reusable user interface. Parent shows/hides elements and calls update methods on score/lives events.
# Dynamically discovers result-timers in the game tree and displays countdown labels.

extends Control

@export var display_mode: CommonEnums.DisplayMode = CommonEnums.DisplayMode.P1_P2_SCORE
@export var display_lives: bool = false
@export var animate_score: bool = true
@export var score_animation_duration: float = 0.3

var elements = CommonEnums.Element

var _displayed_points: int = 0
var _displayed_p1: int = 0
var _displayed_p2: int = 0

# Result-timer tracking: array of { timer: Node, label: Label }
var _result_timer_entries: Array = []
var _connected_game: Node = null  # Track connected game's timer_tick for cleanup

@onready var parent = get_parent()
@onready var _game_timers_container: VBoxContainer = $GameTimers

# Connect to game state signals (guard with has_signal for flexibility)
func _ready() -> void:
	if parent.has_signal("on_points_changed"):
		parent.on_points_changed.connect(set_points)
	if parent.has_signal("on_multiplier_changed"):
		parent.on_multiplier_changed.connect(set_multiplier)
	if parent.has_signal("lives_changed"):
		parent.lives_changed.connect(set_lives)
	if parent.has_signal("timer_tick"):
		parent.timer_tick.connect(_on_any_timer_tick)
	# Note: when parent is AO, timer_tick comes from the game's UGS — 
	# connected during _discover_result_timers() instead
	if parent.has_signal("on_p1_score"):
		parent.on_p1_score.connect(set_p1_score)
	if parent.has_signal("on_p2_score"):
		parent.on_p2_score.connect(set_p2_score)
	if parent.has_signal("state_changed"):
		parent.state_changed.connect(_on_state_changed)
	
	# Discover result-timers after parent tree is ready
	_discover_result_timers()

func _on_state_changed(new_state: CommonEnums.State) -> void:
	match new_state:
		CommonEnums.State.ATTRACT:
			_hide_play_ui()
			show_element(elements.ATTRACT_TEXT)
		CommonEnums.State.PLAYING:
			hide_element(elements.ATTRACT_TEXT)
			_discover_result_timers()  # Re-discover now that game is in the tree
			_show_play_ui()
		CommonEnums.State.GAME_OVER:
			hide_element(elements.ATTRACT_TEXT)
			_hide_play_ui()

func _show_play_ui() -> void:
	match display_mode:
		CommonEnums.DisplayMode.P1_P2_SCORE:
			show_element(elements.P1_SCORE)
			show_element(elements.P2_SCORE)
		CommonEnums.DisplayMode.POINTS_MULTIPLIER:
			show_element(elements.POINTS)
			show_element(elements.MULTIPLIER)
	
	if display_lives:
		show_element(elements.LIVES)
	
	# Show game timers if any were found
	if not _result_timer_entries.is_empty():
		show_element(elements.GAME_TIMER)

func _hide_play_ui() -> void:
	hide_element(elements.P1_SCORE)
	hide_element(elements.P2_SCORE)
	hide_element(elements.POINTS)
	hide_element(elements.MULTIPLIER)
	hide_element(elements.LIVES)
	hide_element(elements.GAME_TIMER)

# Update points display (with optional tick-up animation)
func set_points(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_points != target:
		_animate_score("_displayed_points", target, $Points/PointsNumber, "_points_tween")
	else:
		_displayed_points = target
		$Points/PointsNumber.text = str(target)

# Update multiplier display (handles float values)
func set_multiplier(new_multiplier) -> void:
	var val = float(new_multiplier)
	if val == int(val):
		$Multiplier/MultiplierNumber.text = str(int(val)) + "x"
	else:
		$Multiplier/MultiplierNumber.text = "%.1fx" % val

# Update lives display
func set_lives(new_lives) -> void:
	$Lives/LivesNumber.text = str(int(new_lives))

# Update player 1 score (with optional tick-up animation)
func set_p1_score(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_p1 != target:
		_animate_score("_displayed_p1", target, $"P1 Score", "_p1_tween")
	else:
		_displayed_p1 = target
		$"P1 Score".text = str(target)

# Update player 2 score (with optional tick-up animation)
func set_p2_score(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_p2 != target:
		_animate_score("_displayed_p2", target, $"P2 Score", "_p2_tween")
	else:
		_displayed_p2 = target
		$"P2 Score".text = str(target)

# Animate a score value ticking up from current to target
func _animate_score(prop: String, target: int, label: Node, tween_prop: String) -> void:
	# Kill any existing tween for this score
	var old_tween: Tween = get(tween_prop)
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	
	var current: int = get(prop)
	var new_tween = create_tween()
	new_tween.tween_method(func(val): label.text = str(int(val)), float(current), float(target), score_animation_duration)
	set(tween_prop, new_tween)
	set(prop, target)

# Fallback timer handler — kept for compatibility
func set_timer(_new_time) -> void:
	pass

# --- Result Timer Discovery ---

# Find all timer nodes in the parent tree that have emit_result_on_expire == true
func _discover_result_timers() -> void:
	# Clean up old timer labels and connections from previous game
	_cleanup_timer_display()
	
	_find_result_timers_recursive(parent)
	
	if _result_timer_entries.is_empty():
		_game_timers_container.visible = false

# Free old dynamic labels and disconnect from previous game's timer_tick
func _cleanup_timer_display() -> void:
	# Free dynamic labels
	for entry in _result_timer_entries:
		var label: Label = entry["label"]
		if is_instance_valid(label):
			label.queue_free()
	_result_timer_entries.clear()
	
	# Disconnect from previous game's timer_tick
	if _connected_game and is_instance_valid(_connected_game):
		if _connected_game.has_signal("timer_tick") and _connected_game.timer_tick.is_connected(_on_any_timer_tick):
			_connected_game.timer_tick.disconnect(_on_any_timer_tick)
	_connected_game = null

func _find_result_timers_recursive(node: Node) -> void:
	# Check if this node is a result-timer (has the property and it's enabled)
	if "emit_result_on_expire" in node and node.emit_result_on_expire:
		_create_timer_label(node)
	
	for child in node.get_children():
		_find_result_timers_recursive(child)

# Create a dynamic label for a discovered result-timer
func _create_timer_label(timer_node: Node) -> void:
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Use the timer's LabelSettings resource
	var settings = LabelSettings.new()
	settings.font = load("res://Assets/Fonts/Kenney Pixel.ttf")
	settings.font_size = 32
	
	# Color based on result type: white for victory, red for defeat
	if "result" in timer_node:
		match timer_node.result:
			CommonEnums.Result.VICTORY:
				settings.font_color = Color.WHITE
			CommonEnums.Result.DEFEAT:
				settings.font_color = Color.RED
	else:
		settings.font_color = Color.WHITE
	
	label.label_settings = settings
	_game_timers_container.add_child(label)
	
	# Connect to this timer's game ancestor's timer_tick signal
	# (needed when parent is AO — the AO doesn't have timer_tick, the game's UGS does)
	var timer_game = _find_game_ancestor(timer_node)
	if timer_game and timer_game.has_signal("timer_tick"):
		if not timer_game.timer_tick.is_connected(_on_any_timer_tick):
			timer_game.timer_tick.connect(_on_any_timer_tick)
		_connected_game = timer_game  # Track for cleanup
	
	# Store reference for updates
	_result_timer_entries.append({
		"timer": timer_node,
		"label": label
	})

# Walk up the tree to find the nearest UniversalGameScript ancestor
func _find_game_ancestor(node: Node) -> Node:
	var current = node.get_parent()
	while current:
		if current is UniversalGameScript:
			return current
		current = current.get_parent()
	return null

# Called whenever any timer ticks — update all result-timer labels
func _on_any_timer_tick(_time) -> void:
	_update_timer_labels()

# Update all result-timer labels with current time values
func _update_timer_labels() -> void:
	for entry in _result_timer_entries:
		var timer_node = entry["timer"]
		var label: Label = entry["label"]
		
		if not is_instance_valid(timer_node):
			continue
		
		var current_time: float = timer_node._current_time
		label.text = "%d:%02d" % [int(current_time) / 60, int(current_time) % 60]

# Show UI element by type
func show_element(element: CommonEnums.Element) -> void:
	match element:
		elements.WIN_TEXT: $"Win Text".visible = true
		elements.LOSE_TEXT: $"Lose Text".visible = true
		elements.CONTINUE_TEXT: $"Continue Text".visible = true
		elements.P1_SCORE: $"P1 Score".visible = true
		elements.P2_SCORE: $"P2 Score".visible = true
		elements.ATTRACT_TEXT: $"Attract Text".visible = true
		elements.LIVES: 
			$Lives.visible = true
			$Lives/LivesNumber.visible = true
		elements.POINTS: 
			$Points.visible = true
			$Points/PointsNumber.visible = true
		elements.MULTIPLIER: 
			$Multiplier.visible = true
			$Multiplier/MultiplierNumber.visible = true
		elements.CONTROL_TEXT: $"Attract Text/ControlText".visible = true
		elements.GAME_TIMER:
			_game_timers_container.visible = true

# Hide UI element by type
func hide_element(target_element: CommonEnums.Element) -> void:
	match target_element:
		elements.WIN_TEXT: $"Win Text".visible = false
		elements.LOSE_TEXT: $"Lose Text".visible = false
		elements.CONTINUE_TEXT: $"Continue Text".visible = false
		elements.P1_SCORE: $"P1 Score".visible = false
		elements.P2_SCORE: $"P2 Score".visible = false
		elements.ATTRACT_TEXT: $"Attract Text".visible = false
		elements.LIVES:
			$Lives.visible = false
			$Lives/LivesNumber.visible = false
		elements.POINTS: 
			$Points.visible = false
			$Points/PointsNumber.visible = false
		elements.MULTIPLIER: 
			$Multiplier.visible = false
			$Multiplier/MultiplierNumber.visible = false
		elements.CONTROL_TEXT: $"Attract Text/ControlText".visible = false
		elements.GAME_TIMER:
			_game_timers_container.visible = false