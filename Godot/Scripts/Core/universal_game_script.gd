# Master class for game coordinators. State machine, signal routing, score tracking, collision matrix setup.
class_name UniversalGameScript extends Node2D

@export var game_title: String
@export var collision_groups: Array[CollisionGroup]

var states = CommonEnums.State
var collision_matrix: CollisionMatrix
var p1_score: int = 0
var p2_score: int = 0

var _collision_dict: Dictionary
var _current_state: CommonEnums.State = states.ATTRACT
var _current_score: int = 0
var _current_multiplier: int = 1

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

var current_multiplier: int:
	get:
		return _current_multiplier
	set(value):
		if _current_multiplier != value:
			_current_multiplier = value
			on_multiplier_changed.emit(_current_multiplier)

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

# Signals TO other components, they listen and react
signal on_game_start
signal on_game_end
signal on_game_over(final_score: int)
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: int)
signal state_changed(new_state: CommonEnums.State)
signal on_p1_score(p1_score: int)
signal on_p2_score(p2_score: int)

# Initialize collision matrix and auto-configure all bodies
func _ready() -> void:
	if not collision_groups.is_empty():
		_collision_dict.clear()
		for cg in collision_groups:
			_collision_dict[cg.group_name] = cg.targets
		
		collision_matrix = CollisionMatrix.new()
		collision_matrix.initialize(self)
		collision_matrix.setup(_collision_dict)

	
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
	#print("starting game!")
	current_state = states.PLAYING
	on_game_start.emit()

# Emit game end signal for cleanup
func end_game() -> void:
	on_game_end.emit()

# Show win UI and transition to GAME_OVER
func p1_win() -> void:
	current_state = states.GAME_OVER
	on_game_over.emit()
	$Interface.show_element(CommonEnums.Element.WIN_TEXT)
	$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)
	print("Game: ", game_title, " Score: ", current_score)

# Show lose UI and transition to GAME_OVER
func p1_lose() -> void:
	current_state = states.GAME_OVER
	on_game_over.emit()
	$Interface.show_element(CommonEnums.Element.LOSE_TEXT)
	$Interface.show_element(CommonEnums.Element.CONTINUE_TEXT)
	print("Game: ", game_title, " Score: ", current_score)

# Pause the game
func pause_game() -> void:
	current_state = states.PAUSED

# Resume the game
func unpause_game() -> void:
	current_state = states.PLAYING

# Add points to score and emit update
func add_score(amount: int) -> void:
	current_score += amount * current_multiplier
	
# Add multiplier and emit update
func add_multiplier(amount: int) -> void:
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

func add_p1_score(amount) -> void:
	p1_score += amount * current_multiplier
	on_p1_score.emit(p1_score)

func add_p2_score(amount) -> void:
	p2_score += amount * current_multiplier
	on_p2_score.emit(p2_score)

static func find_ancestor(node: Node) -> UniversalGameScript:
	var parent = node.get_parent()
	while parent:
		if parent is UniversalGameScript:
			return parent
		parent = parent.get_parent()
	return null
