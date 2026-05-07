# Master class for game coordinators. State machine, signal routing, score tracking, collision matrix setup.
# Supports STANDALONE mode (self-contained with input handling) and ARCADE mode (orchestrator-controlled).

class_name UniversalGameScript extends Node2D

enum Mode { STANDALONE, ARCADE }

@export var game_title: String
@export var collision_groups: Array[CollisionGroup]
@export var mode: Mode = Mode.STANDALONE
@export var vector_monitor: bool = false

var states = CommonEnums.State
var collision_matrix: CollisionMatrix
var p1_score: int = 0
var p2_score: int = 0

var _collision_dict: Dictionary
var _current_state: CommonEnums.State = states.ATTRACT
var _current_score: int = 0
var _current_multiplier: float = 1.0

# Public state property with automatic signal emission on change
var current_state: CommonEnums.State:
	get:
		return _current_state
	set(value):
		if _current_state != value:
			_current_state = value
			state_changed.emit(_current_state)

# Properties with auto-emit setters
var current_score: int:
	get:
		return _current_score
	set(value):
		if _current_score != value:
			_current_score = value
			on_points_changed.emit(_current_score)

var current_multiplier: float:
	get:
		return _current_multiplier
	set(value):
		if _current_multiplier != value:
			_current_multiplier = value
			on_multiplier_changed.emit(_current_multiplier)

# Arcade bonus multiplier — set by ArcadeOrchestrator via signal
var arcade_bonus: float = 0.0

# Signals FROM other components, they call parent.{signal}.emit()
signal victory
signal defeat
@warning_ignore("unused_signal")
signal group_cleared(group_name: String)
@warning_ignore("unused_signal")
signal lives_changed(new_lives: int)
@warning_ignore("unused_signal")
signal lives_depleted
@warning_ignore("unused_signal")
signal timer_tick(current_time: float)
@warning_ignore("unused_signal")
signal timer_expired(timer_id: String)
@warning_ignore("unused_signal")
signal spawning_wave(director, wave_number: int)
@warning_ignore("unused_signal")
signal spawning_wave_complete(director, wave_number: int)
@warning_ignore("unused_signal")
signal group_member_removed(group_name: String)
@warning_ignore("unused_signal")
signal piece_settled
@warning_ignore("unused_signal")
signal hold_requested
@warning_ignore("unused_signal")
signal t_spin_detected(is_t_spin: bool, is_mini: bool)

# Signals TO other components, they listen and react
signal on_game_start
signal on_game_end
signal on_game_over(final_score: int)
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: float)
signal state_changed(new_state: CommonEnums.State)
signal on_p1_score(p1_score: int)
signal on_p2_score(p2_score: int)

# Initialize collision matrix and auto-configure all bodies
func _ready() -> void:
	# Keep this node alive during pause so it can detect start input
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure children respect pause despite our ALWAYS mode
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Freeze game in ATTRACT mode until started
	get_tree().paused = true
	
	if not collision_groups.is_empty():
		_collision_dict.clear()
		for cg in collision_groups:
			_collision_dict[cg.group_name] = cg.targets
		
		collision_matrix = CollisionMatrix.new()
		collision_matrix.initialize(self)
		collision_matrix.setup(_collision_dict)
	
	victory.connect(p1_win)
	defeat.connect(p1_lose)

# STANDALONE mode: route start/pause input to appropriate methods
func _input(event: InputEvent) -> void:
	if mode != Mode.STANDALONE:
		return
	
	if event.is_action_pressed("start"):
		if current_state == states.ATTRACT:
			get_viewport().set_input_as_handled()
			start_game()
		elif current_state == states.GAME_OVER:
			get_viewport().set_input_as_handled()
			_on_restart_pressed()
	
	if event.is_action_pressed("pause"):
		if current_state == states.GAME_OVER:
			get_viewport().set_input_as_handled()
			_on_quit_pressed()

# Transition to PLAYING state and initialize game
func start_game() -> void:
	get_tree().paused = false
	current_state = states.PLAYING
	on_game_start.emit()

# Emit game end signal for cleanup
func end_game() -> void:
	on_game_end.emit()

# Show win UI and transition to GAME_OVER
func p1_win() -> void:
	if current_state == states.GAME_OVER:
		return
	current_state = states.GAME_OVER
	on_game_over.emit(current_score)
	if mode == Mode.STANDALONE:
		$Interface.show_element(CommonEnums.Element.WIN_TEXT)
		$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)
	print("Game: ", game_title, " Score: ", current_score)

# Show lose UI and transition to GAME_OVER
func p1_lose() -> void:
	if current_state == states.GAME_OVER:
		return
	current_state = states.GAME_OVER
	on_game_over.emit(current_score)
	if mode == Mode.STANDALONE:
		$Interface.show_element(CommonEnums.Element.LOSE_TEXT)
		$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)
	print("Game: ", game_title, " Score: ", current_score)

# Called externally (by orchestrator or input router) when start is pressed in ATTRACT
func _on_start_pressed() -> void:
	if current_state == states.ATTRACT:
		start_game()

# Called externally when restart is requested in GAME_OVER
func _on_restart_pressed() -> void:
	if current_state == states.GAME_OVER:
		get_tree().reload_current_scene()

# Called externally when quit is requested in GAME_OVER
func _on_quit_pressed() -> void:
	if current_state == states.GAME_OVER:
		get_tree().quit()

# Pause the game
func pause_game() -> void:
	current_state = states.PAUSED

# Resume the game
func unpause_game() -> void:
	current_state = states.PLAYING

# Add points to score and emit update
func add_score(amount: int) -> void:
	var effective_mult = current_multiplier + arcade_bonus
	var result = int(amount * effective_mult)
	#print("[UGS] add_score: %d × %.1f (mult %.1f + arcade %.1f) = %d → total %d" % [
	#	amount, effective_mult, current_multiplier, arcade_bonus, result, current_score + result])
	current_score = current_score + result
	
# Add multiplier and emit update
func add_multiplier(amount: float) -> void:
	current_multiplier += amount

# Configure collision matrix with group relationships
func setup_collision_groups(groups: Dictionary) -> void:
	collision_matrix.setup(groups)

# Set current state
func set_state(new_state: CommonEnums.State) -> void:
	current_state = new_state

# Get current state
func get_state() -> CommonEnums.State:
	return current_state

# Add to player 1 score with current multiplier and emit update
func add_p1_score(amount) -> void:
	var effective_mult = current_multiplier + arcade_bonus
	var result = int(amount * effective_mult)
	#print("[UGS] add_p1_score: %d × %.1f (mult %.1f + arcade %.1f) = %d → total %d" % [
	#	amount, effective_mult, current_multiplier, arcade_bonus, result, p1_score + result])
	p1_score = p1_score + result
	on_p1_score.emit(p1_score)
	
# Add to player 2 score with current multiplier and emit update
func add_p2_score(amount) -> void:
	var effective_mult = current_multiplier + arcade_bonus
	var result = int(amount * effective_mult)
	#print("[UGS] add_p2_score: %d × %.1f (mult %.1f + arcade %.1f) = %d → total %d" % [
	#	amount, effective_mult, current_multiplier, arcade_bonus, result, p2_score + result])
	p2_score = p2_score + result
	on_p2_score.emit(p2_score)

# Receive arcade bonus from ArcadeOrchestrator
func set_arcade_bonus(bonus: float) -> void:
	arcade_bonus = bonus

# Walk up the tree to find the nearest UniversalGameScript ancestor
static func find_ancestor(node: Node) -> UniversalGameScript:
	var parent = node.get_parent()
	while parent:
		if parent is UniversalGameScript:
			return parent
		parent = parent.get_parent()
	return null
