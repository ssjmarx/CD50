## cd_scaler.gd
## Produces: an abstract float-scaling resource contract (base, min, max, lifecycle).
## Consumes: nothing — base class; subclasses consume CDGame state in evaluate().
class_name CDScaler extends Resource

## the baseline value before scaling
@export var base: float = 1.0

## minimum clamped value
@export var minimum: float = 0.0

## maximum clamped value
@export var maximum: float = 10.0

## cached game reference for group registry / bus access
var _game: CDGame

## --- Lifecycle ---

## Store game reference — override to connect signals.
func initialize(game: CDGame) -> void:
	_game = game

## Return the scaled value for the current game state.
func evaluate() -> float:
	return base

## Reset internal state for game restart.
func reset() -> void:
	pass