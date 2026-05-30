# CDSelector
# Abstract base class for transition entity selectors
# Stores game ref and defines the select() interface for subclasses

class_name CDSelector extends Resource

# game reference for group registry access
var _game: CDGame

# store the CDGame reference during initialization
func initialize(game: CDGame) -> void:
	_game = game

# override in subclasses — returns a subset of candidates
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	return candidates

# clear the game reference on reset
func reset() -> void:
	_game = null
