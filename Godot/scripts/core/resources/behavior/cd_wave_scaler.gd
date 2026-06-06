## CDWaveScaler
## Converts wave number into a scaled float value via linear interpolation with clamping
## Reads wave number from game blackboard (set by WaveCard)

class_name CDWaveScaler extends CDScaler

## --- exports ---

## amount added per wave after wave 1 (negative = decreases over time)
@export var per_wave: float = -0.3

## blackboard key to read the current wave number from
@export var wave_key: StringName = &"wave_number"

### timer for debug prints
#var _previous_wave: int = 0

## --- evaluation ---

## return the scaled value for the current wave (read from blackboard)
func evaluate() -> float:
	var wave_number: int = 1
	if _game and _game.blackboard.has(wave_key):
		wave_number = _game.blackboard[wave_key]
		#if _previous_wave != wave_number:
			#_previous_wave = wave_number
			#print("new wave number: ", wave_number)
	var result := clampf(base + per_wave * (wave_number - 1), minimum, maximum)
	
	return result

## --- reset ---

## no internal state to reset — blackboard is the source of truth
func reset() -> void:
	pass
