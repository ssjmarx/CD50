## abstract base class for transition entity selectors
class_name CDSelector extends Resource

var _game: CDGame

func initialize(game: CDGame) -> void:
	_game = game

## override in subclasses. returns a subset of candidates.
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	return candidates

func reset() -> void:
	_game = null
