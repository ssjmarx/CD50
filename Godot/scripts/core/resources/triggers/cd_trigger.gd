## abstract base class for all state machine transition triggers
class_name CDTrigger extends Resource

## triggers come in evaluative (condition) and event (moment) flavors
var is_evaluative: bool = false
var _game: CDGame

func initialize(game: CDGame) -> void:
	_game = game

## overridden by derived classes for their checking
func evaluate(_delta: float) -> bool:
	return false

func is_condition_met() -> bool:
	return false

func reset() -> void:
	_game = null
