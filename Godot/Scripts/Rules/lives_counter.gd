# Manages player lives for games with lives systems (Asteroids, Breakout).

extends Node

@export var max_lives: int = 3 # Maximum lives player can have
@export var current_lives: int = 3 # Current number of lives

@onready var parent = get_parent() # Reference to game script

# Decrement lives by 1 and emit signals
func lose_life() -> void:
	current_lives -= 1
	parent.lives_changed.emit(current_lives)
	
	# Emit defeat signal when lives reach 0
	if current_lives <= 0:
		parent.lives_depleted.emit()

# Reset lives to maximum value
func reset_lives() -> void:
	current_lives = max_lives
	parent.lives_changed.emit(current_lives)

# Set lives to a specific value
func set_lives(amount: int) -> void:
	current_lives = amount
	parent.lives_changed.emit(current_lives)