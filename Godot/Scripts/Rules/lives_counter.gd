# Manages player lives for games with lives systems (Asteroids, Breakout).

extends UniversalComponent

@export var max_lives: int = 3
@export var defeat_on_zero: bool = true

@onready var current_lives: int = max_lives

# Decrement lives by 1 and emit signals
func lose_life() -> void:
	current_lives -= 1
	game.lives_changed.emit(current_lives)
	
	if current_lives <= 0:
		game.lives_depleted.emit()
		game.defeat.emit()

func extra_life() -> void:
	current_lives += 1
	game.lives_changed.emit(current_lives)

# Reset lives to maximum value
func reset_lives() -> void:
	current_lives = max_lives
	game.lives_changed.emit(current_lives)

# Set lives to a specific value
func set_lives(amount: int) -> void:
	current_lives = amount
	game.lives_changed.emit(current_lives)
