# CDTrigger
# Abstract base class for all state machine transition triggers
# Two flavors: evaluative (continuous condition) and event (moment-based)

class_name CDTrigger extends Resource

# true = continuous condition check, false = moment-based event
var is_evaluative: bool = false

# game reference for group registry and bus access
var _game: CDGame

# store the CDGame reference during initialization
func initialize(game: CDGame) -> void:
	_game = game

# override in subclasses — return true when trigger should fire
func evaluate(_delta: float) -> bool:
	return false

# override in evaluative subclasses — return current condition state
func is_condition_met() -> bool:
	return false

# clear state and game reference on reset
func reset() -> void:
	_game = null