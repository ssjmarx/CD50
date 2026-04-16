# Master class for game coordinators. State machine, signal routing, score tracking, collision matrix setup.
class_name UniversalGameScript extends Node2D

@export var game_title: String
@export var collision_groups: Dictionary

var states = CommonEnums.State
var current_score = 0
var current_multiplier = 0
var collision_matrix: CollisionMatrix
var _current_state: CommonEnums.State = states.PLAYING
var p1_score: int = 0
var p2_score: int = 0

# Public state property with automatic signal emission on change
var current_state: CommonEnums.State:
	get:
		return _current_state
	set(value):
		if _current_state != value:
			_current_state = value
			state_changed.emit(_current_state)

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
signal timer_expired
@warning_ignore("unused_signal")
signal spawning_wave(director, wave_number: int)
@warning_ignore("unused_signal")
signal spawning_wave_complete(director, wave_number: int)

# Signals TO other components, they listen and react
signal on_game_start
signal on_game_end
signal on_game_over(final_score: int)
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: int)
signal state_changed(new_state: CommonEnums.State)
signal on_p1_score(amount: int)
signal on_p2_score(amount: int)

# Initialize collision matrix and auto-configure all bodies
func _ready() -> void:
	if collision_groups:
		collision_matrix = CollisionMatrix.new()
		collision_matrix.initialize(self)
	
	victory.connect(p1_win)
	defeat.connect(p1_lose)

# Handle state transitions via keyboard input
func _unhandled_input(event: InputEvent) -> void:
	if current_state == states.ATTRACT and event is InputEventKey and event.pressed:
		start_game()
		return
	
	if current_state == states.GAME_OVER and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

# Transition to PLAYING state and initialize game
func start_game() -> void:
	current_state = states.PLAYING
	on_game_start.emit()
	_initialize_gameplay()

# Override in subclasses to spawn entities and setup game rules
func _initialize_gameplay() -> void:
	pass

# Emit game end signal for cleanup
func end_game() -> void:
	on_game_end.emit()

# Show win UI and transition to GAME_OVER
func p1_win() -> void:
	current_state = states.GAME_OVER
	on_game_over.emit()
	$Interface.show_element(CommonEnums.Element.WIN_TEXT)
	$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)

# Show lose UI and transition to GAME_OVER
func p1_lose() -> void:
	current_state = states.GAME_OVER
	on_game_over.emit()
	$Interface.show_element(CommonEnums.Element.LOSE_TEXT)
	$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)

# Pause the game
func pause_game() -> void:
	current_state = states.PAUSED

# Resume the game
func unpause_game() -> void:
	current_state = states.PLAYING

# Add points to score and emit update
func add_score(amount: int) -> void:
	current_score += amount
	on_points_changed.emit(current_score)
	
# Set multiplier and emit update
func set_multiplier(new_value: int) -> void:
	current_multiplier = new_value
	on_multiplier_changed.emit(current_multiplier)

# Configure collision matrix with group relationships
func setup_collision_groups(groups: Dictionary) -> void:
	collision_matrix.setup(groups)

# Set current state
func set_state(new_state: CommonEnums.State) -> void:
	current_state = new_state

# Get current state
func get_state() -> CommonEnums.State:
	return current_state

func add_p1_score(amount) -> void:
	p1_score += amount
	on_p1_score.emit(amount)

func add_p2_score(amount) -> void:
	p2_score += amount
	on_p2_score.emit(amount)

static func find_ancestor(node: Node) -> UniversalGameScript:
	var parent = node.get_parent()
	while parent:
		if parent is UniversalGameScript:
			return parent
		parent = parent.get_parent()
	return null
