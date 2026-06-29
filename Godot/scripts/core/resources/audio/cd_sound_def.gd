## cd_sound_def.gd
## Produces: a complete sound effect definition (wave, effect, volume, notes).
## Consumes: nothing — pure data resource consumed by CDSoundBank.play_one_shot().
class_name CDSoundDef extends Resource

## oscillator waveform for this sound
@export var wave_shape: CDEnums.WaveShape = CDEnums.WaveShape.SQUARE

## frequency/amplitude modulation effect (tremolo, vibrato, decay, etc.)
@export var effect: CDEnums.Effect = CDEnums.Effect.NONE

## linear volume level (0.0–1.0, 0.2 is a safe baseline)
@export var volume: float = 0.2

## note sequence — 1 note = one-shot, 2+ notes = jingle played sequentially
@export var notes: Array[CDNote] = []
