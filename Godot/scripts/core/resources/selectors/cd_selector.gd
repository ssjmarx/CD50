## cd_selector.gd
## Produces: an abstract selector contract returning a subset of candidate entities.
## Consumes: candidate entities; an optional CDGame ref cached via initialize().
class_name CDSelector extends Resource

## game reference for group registry access
var _game: CDGame

## store the CDGame reference during initialization
func initialize(game: CDGame) -> void:
	_game = game

## Override in subclasses — returns a subset of candidates (base passes through unchanged).
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	return candidates

## clear the game reference on reset
func reset() -> void:
	_game = null
