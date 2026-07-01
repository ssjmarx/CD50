## cd_utilities.gd
## Produces: pure static utility helpers for spawning, expression eval, and audio waveforms.
## Consumes: CDEntity, CDSpawnContext, CDEnums — all passed in as arguments.
class_name CDUtilities

## sample rate for procedural sound generation
const MIX_RATE: int = 11025

## Apply a CDSpawnContext to an entity before it enters the tree.
static func apply_spawn_context(entity: CDEntity, context: CDSpawnContext) -> void:
	if context == null:
		return

	entity.velocity = context.velocity

	if context.use_random_angle:
		var speed := entity.velocity.length()
		var angle := Vector2.from_angle(randf_range(context.random_angle_min, context.random_angle_max))
		entity.velocity = angle * speed

	if context.random_flip_h:
		entity.velocity.x *= [-1, 1].pick_random()

	if context.random_flip_v:
		entity.velocity.y *= [-1, 1].pick_random()

	entity.rotation = context.rotation

	for group in context.additional_groups:
		entity.add_to_group(group)

## Evaluate a string expression with named variables, returning the result as int.
static func evaluate_int(equation: String, var_names: PackedStringArray, var_values: Array, context_name: String) -> int:
	var expr := Expression.new()
	var error := expr.parse(equation, var_names)
	if error != OK:
		push_error("%s: failed to parse equation '%s': %s" % [context_name, equation, expr.get_error_text()])
		return 0
	var result = expr.execute(var_values)
	if expr.has_execute_failed():
		push_error("%s: failed to execute equation '%s': %s" % [context_name, equation, expr.get_error_text()])
		return 0
	return int(result)

## --- Audio / Waveform ---

## Convert a MIDI note number to its frequency in Hz.
static func freq_from_note(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## Return a modified frequency after applying a frequency effect.
static func apply_freq_effect(freq: float, t: float, effect: int) -> float:
	match effect:
		CDEnums.Effect.WARBLE:
			return freq + sin(TAU * 5.0 * t) * 30.0
		CDEnums.Effect.SWEEP_DOWN:
			return freq * maxf(0.1, 1.0 - t * 2.0)
		CDEnums.Effect.SWEEP_UP:
			return freq * (1.0 + t * 4.0)
		CDEnums.Effect.WARBLE_WIDE:
			return freq + sin(TAU * 8.0 * t) * freq * 0.06
	return freq

## Return a raw waveform sample for a phase position and wave shape.
static func wave_sample(phase: float, wave_shape: int) -> float:
	match wave_shape:
		CDEnums.WaveShape.SINE:
			return sin(TAU * phase)
		CDEnums.WaveShape.SQUARE:
			return sign(sin(TAU * phase))
		CDEnums.WaveShape.SAWTOOTH:
			return 2.0 * (phase - floor(phase + 0.5))
		CDEnums.WaveShape.TRIANGLE:
			return 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
		CDEnums.WaveShape.NOISE:
			var noise: float = randf() * 2.0 - 1.0
			var tone: float = sin(TAU * phase)
			return lerp(tone, noise, 0.5)
		CDEnums.WaveShape.PULSE_25:
			return sign(sin(TAU * phase) - 0.5)
		CDEnums.WaveShape.PULSE_12:
			return sign(sin(TAU * phase) - 0.75)
		CDEnums.WaveShape.PURE_NOISE:
			return randf() * 2.0 - 1.0
	return 0.0

## Return a modified sample after applying an amplitude effect.
static func apply_amp_effect(sample: float, t: float, note_progress: float, effect: int) -> float:
	match effect:
		CDEnums.Effect.TREMOLO:
			return sample * (0.5 + 0.5 * sin(TAU * 4.0 * t))
		CDEnums.Effect.DECAY:
			return sample * maxf(0.0, 1.0 - note_progress)
		CDEnums.Effect.FAST_DECAY:
			return sample * pow(maxf(0.0, 1.0 - note_progress), 3.0)
		CDEnums.Effect.RIPPLE:
			return sample * (1.0 if sin(TAU * 16.0 * t) > 0.0 else 0.2)
	return sample
