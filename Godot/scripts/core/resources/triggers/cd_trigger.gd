## cd_trigger.gd
## Produces: an abstract trigger contract (event vs evaluative) for state transitions.
## Consumes: an injected CDGame ref (cached via initialize).
class_name CDTrigger extends Resource

## true = continuous condition check, false = moment-based event
var is_evaluative: bool = false

## game reference for group registry and bus access
var _game: CDGame

## store the CDGame reference during initialization
func initialize(game: CDGame) -> void:
	_game = game

## override in subclasses — return true when trigger should fire
func evaluate(_delta: float) -> bool:
	return false

## override in evaluative subclasses — return current condition state
func is_condition_met() -> bool:
	return false

## clear state and game reference on reset
func reset() -> void:
	_game = null
