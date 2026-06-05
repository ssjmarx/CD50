## CDScaler
## Abstract base class for float value scaling resources
## Provides base value, clamping, and a game-aware lifecycle

class_name CDScaler extends Resource

## --- exports ---

## the baseline value before scaling
@export var base: float = 1.0

## minimum clamped value
@export var minimum: float = 0.0

## maximum clamped value
@export var maximum: float = 10.0

## --- state ---

## cached game reference for group registry / bus access
var _game: CDGame

## --- lifecycle ---

## store game reference — override to connect signals
func initialize(game: CDGame) -> void:
	_game = game

## return the scaled value for the current game state
func evaluate() -> float:
	return base

## reset internal state for game restart
func reset() -> void:
	pass