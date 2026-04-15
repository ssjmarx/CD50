# Master class for game coordinators. State machine, signal routing, score tracking, collision matrix setup.
class_name UniversalGameScript extends Node2D

var states = CommonEnums.State # Reference to state enum
var current_score = 0 # Player score
var current_multiplier = 0 # Score multiplier
var collision_matrix: CollisionMatrix # Auto-configures collision layers/masks
var _current_state: CommonEnums.State = states.ATTRACT # Internal state storage

# Public state property with automatic signal emission on change
var current_state: CommonEnums.State:
	get:
		return _current_state
	set(value):
		if _current_state != value:
			_current_state = value
			state_changed.emit(_current_state)

# Game display name
@export var game_title: String

# Signals from Rules components (connect to these)
@warning_ignore("unused_signal")
signal group_cleared(group_name: String) # Emitted when monitored group empties
@warning_ignore("unused_signal")
signal victory # Emitted on win condition
@warning_ignore("unused_signal")
signal defeat # Emitted on lose condition
@warning_ignore("unused_signal")
signal lives_changed(new_lives: int) # Lives count changed
@warning_ignore("unused_signal")
signal lives_depleted # Lives reached zero
@warning_ignore("unused_signal")
signal timer_tick(current_time: float) # Timer tick event
@warning_ignore("unused_signal")
signal timer_expired # Timer reached limit

# Signals emitted to Rules/components (connect from these)
signal on_game_start # Game started, components should activate
signal on_game_end # Game ended, cleanup
signal on_game_over(final_score: int) # Game over state reached
signal on_points_changed(new_score: int) # Score updated
signal on_multiplier_changed(new_multiplier: int) # Multiplier updated
signal state_changed(new_state: CommonEnums.State) # State transition

# Initialize collision matrix and auto-configure all bodies
func _ready() -> void:
	collision_matrix = CollisionMatrix.new()
	collision_matrix.initialize(self)

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
func setup_collision_groups(collision_groups: Dictionary) -> void:
	collision_matrix.setup(collision_groups)

# Set current state
func set_state(new_state: CommonEnums.State) -> void:
	current_state = new_state

# Get current state
func get_state() -> CommonEnums.State:
	return current_state
