## CDWaveScaler
## Converts wave number into a scaled float value via linear interpolation with clamping
## Listens to game bus signals for wave number updates

class_name CDWaveScaler extends CDScaler

## --- exports ---

## amount added per wave after wave 1 (negative = decreases over time)
@export var per_wave: float = -0.3

## game bus signals that carry wave number as first int argument
@export var listen_signals: Array[StringName] = [&"wave_changed"]

## --- state ---

## current wave number (starts at 1)
var _wave_number: int = 1

## --- lifecycle ---

## connect to game bus signals for wave updates
func initialize(game: CDGame) -> void:
	super.initialize(game)
	for sig in listen_signals:
		if sig != &"":
			_game.bus_connect(sig, _on_wave_signal)

## receive wave number from game bus signal
func _on_wave_signal(wave: int = 0) -> void:
	_wave_number = wave

## --- evaluation ---

## return the scaled value for the current wave
func evaluate() -> float:
	return clampf(base + per_wave * (_wave_number - 1), minimum, maximum)

## --- reset ---

## reset to initial wave for game restart
func reset() -> void:
	_wave_number = 1