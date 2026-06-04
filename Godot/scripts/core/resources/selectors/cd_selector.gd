## CDSelector
## Abstract base class for transition entity selectors
## Stores game ref and defines the select() interface for subclasses

class_name CDSelector extends Resource

## game reference for group registry access
var _game: CDGame

## store the CDGame reference during initialization
func initialize(game: CDGame) -> void:
	_game = game

## override in subclasses — returns a subset of candidates
## source_position is the director's global_position for distance-based selectors
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	return candidates

## clear the game reference on reset
func reset() -> void:
	_game = null
