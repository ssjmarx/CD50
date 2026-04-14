# Master class for all game scripts.  Contains state machine, handles objective signal routing, and sets up collision mattrix.

extends Node2D

const user_interface = preload("res://Scenes/Components/interface.tscn")

var states = CommonEnums.State
var current_state = states.ATTRACT
var current_score = 0
var current_multiplier = 0
var collision_matrix: CollisionMatrix

@export var game_title: String

signal on_game_start
signal on_game_end
signal on_game_over(final_score: int)
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: int)

func _ready() -> void:
	collision_matrix = CollisionMatrix.new()
	collision_matrix.initialize(self)
	
	var interface = user_interface.instantiate()
	add_child(interface)

func start_game() -> void:
	current_state = states.ATTRACT
	on_game_start.emit()

func end_game() -> void:
	on_game_end.emit()

func game_over() -> void:
	current_state = states.GAME_OVER
	on_game_over.emit(current_score)

func pause_game() -> void:
	current_state = states.PAUSED

func unpause_game() -> void:
	current_state = states.PLAYING

func add_score(amount: int) -> void:
	current_score += amount
	on_points_changed.emit(current_score)
	
func set_multiplier(new_value: int) -> void:
	current_multiplier = new_value
	on_multiplier_changed.emit(current_multiplier)

func setup_collision_groups(collision_groups: Dictionary) -> void:
	collision_matrix.setup(collision_groups)
