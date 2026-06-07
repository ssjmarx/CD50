## CDUtilities
## Pure static utility functions used across V2
## No state, no side effects — call directly via CDUtilities.func_name()

class_name CDUtilities

## sample rate for procedural sound generation
const MIX_RATE: int = 11025

## --- Spawn & Entity ---

## apply a CDSpawnContext to an entity before it enters the tree
static func apply_spawn_context(entity: CDEntity, context: CDSpawnContext) -> void:
	if context == null:
		return

	## set initial velocity from context
	entity.velocity = context.velocity

	## optionally randomize velocity direction within angle range
	if context.use_random_angle:
		var speed := entity.velocity.length()
		var angle := Vector2.from_angle(randf_range(context.random_angle_min, context.random_angle_max))
		entity.velocity = angle * speed

	## optionally flip horizontal/vertical velocity components
	if context.random_flip_h:
		entity.velocity.x *= [-1, 1].pick_random()

	if context.random_flip_v:
		entity.velocity.y *= [-1, 1].pick_random()

	## set initial rotation
	entity.rotation = context.rotation

	## add any extra groups the entity should belong to
	for group in context.additional_groups:
		entity.add_to_group(group)

## --- Expression Evaluation ---

## evaluate a string expression with named variables, returns result as int
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

## convert MIDI note number to frequency in Hz
static func freq_from_note(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

## return modified frequency after applying a frequency effect
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

## return raw waveform sample from phase position for a given wave shape
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

## return modified sample after applying an amplitude effect
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
