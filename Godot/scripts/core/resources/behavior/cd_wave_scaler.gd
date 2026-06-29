## cd_wave_scaler.gd
## Produces: a scaled float based on wave number (linear interpolation + clamp).
## Consumes: CDGame.blackboard for wave number; nothing on write.
class_name CDWaveScaler extends CDScaler

## amount added per wave after wave 1 (negative = decreases over time)
@export var per_wave: float = -0.3

## blackboard key to read the current wave number from
@export var wave_key: StringName = &"wave_number"

## Return the scaled value for the current wave (read from blackboard).
func evaluate() -> float:
	var wave_number: int = 1
	if _game and _game.blackboard.has(wave_key):
		wave_number = _game.blackboard[wave_key]
	var result := clampf(base + per_wave * (wave_number - 1), minimum, maximum)

	return result

## No internal state to reset — blackboard is the source of truth.
func reset() -> void:
	pass