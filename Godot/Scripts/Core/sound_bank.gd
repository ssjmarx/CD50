# Centralized audio pool for one-shot synthesized sounds.
# Pre-warms a fixed pool of AudioStreamPlayer2D + AudioStreamGenerator pairs
# to eliminate per-entity node creation/destruction overhead.
#
# SoundSynth ON_SIGNAL mode routes play_one_shot() through this pool,
# becoming a lightweight config holder + relay instead of creating its own
# audio nodes. CONTINUOUS mode SoundSynth is unaffected.
#
# The centralized _process loop fills ALL active voices in one pass,
# replacing N separate _process functions with a single one.

extends Node

# Audio constants (shared with SoundSynth)
const MIX_RATE: int = 11025
const MAX_VOICES: int = 8
const MAX_FILL_PER_FRAME: int = 256
const MAX_INITIAL_FILL: int = 128

# Wave shape and effect enums (mirrored from SoundSynth for readable match arms)
enum WaveShape { SINE, SQUARE, SAWTOOTH, TRIANGLE, NOISE }
enum Effect { NONE, WARBLE, TREMOLO, SWEEP_DOWN, DECAY }

# Pre-warmed voice pool
var _voices: Array = []
var _has_active: bool = false

# Pre-warm the voice pool with persistent AudioStreamPlayer2D nodes.
# These are created once and reused forever — no per-sound node churn.
func _ready() -> void:
	set_process(false)
	for i in MAX_VOICES:
		var voice := Voice.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		var player := AudioStreamPlayer2D.new()
		player.stream = gen
		add_child(player)
		voice.player = player
		voice.gen = gen
		_voices.append(voice)

# Play a one-shot synthesized sound from the pool.
# Returns true if a voice was claimed, false if all voices busy.
# wave_shape: WaveShape enum value
# effect: Effect enum value
# note: MIDI note number (48-83)
# volume: linear volume (0.0-1.0)
# duration: seconds
# position: world position for spatial audio
# positional: whether to apply distance attenuation
# exclusive: skip if this source already has an active voice
# source_id: get_instance_id() of the calling SoundSynth
func play(wave_shape: int, effect: int, note: int, volume: float,
		duration: float, position: Vector2, positional: bool,
		exclusive: bool, source_id: int) -> bool:
	
	# Exclusive: skip if this source already has an active voice
	if exclusive:
		for v in _voices:
			if v.active and v.source_id == source_id:
				return false
	
	# Check if this source already has an active voice — restart it
	# (matches old per-synth behavior where calling play_one_shot() while
	# still playing would restart on the same AudioStreamPlayer2D)
	var voice: Voice = null
	for v in _voices:
		if v.active and v.source_id == source_id:
			voice = v
			break
	
	# No active voice for this source — find an idle one
	if voice == null:
		voice = _find_idle_voice()
		if voice == null:
			return false
	
	# Configure voice state
	voice.active = true
	voice.source_id = source_id
	voice.wave_shape = wave_shape
	voice.effect = effect
	voice.frame_pos = 0
	voice.phase = 0.0
	voice.shot_end = maxi(1, int(duration * MIX_RATE))
	voice.cached_freq = 440.0 * pow(2.0, (note - 69) / 12.0)
	
	# Configure player
	voice.player.volume_db = linear_to_db(volume)
	if positional:
		voice.player.global_position = position
		voice.player.max_distance = 2000.0
	else:
		# Non-positional: huge max_distance eliminates attenuation
		voice.player.global_position = Vector2.ZERO
		voice.player.max_distance = 2000000.0
	
	if not voice.player.playing:
		voice.player.play()
	voice.playback = voice.player.get_stream_playback()
	
	# Initial fill — capped to prevent audio-gen spikes during collision callbacks.
	# Remaining samples are generated in _process over subsequent frames.
	var available: int = voice.playback.get_frames_available()
	var to_push: int = mini(mini(available, voice.shot_end), MAX_INITIAL_FILL)
	for i in to_push:
		var t: float = float(voice.frame_pos) / MIX_RATE
		var sample: float = _get_sample(voice, t)
		voice.playback.push_frame(Vector2(sample, sample))
		voice.frame_pos += 1
	
	# Ensure centralized fill loop is running
	if not _has_active:
		_has_active = true
		set_process(true)
	
	return true

# Centralized fill loop — processes all active voices in one pass.
# Only runs when there are active voices (enabled/disabled dynamically).
func _process(_delta: float) -> void:
	var any_active := false
	
	for voice in _voices:
		if not voice.active:
			continue
		any_active = true
		
		var to_fill: int = mini(voice.playback.get_frames_available(), MAX_FILL_PER_FRAME)
		var remaining: int = voice.shot_end - voice.frame_pos
		var to_push: int = mini(to_fill, remaining)
		for i in to_push:
			var t: float = float(voice.frame_pos) / MIX_RATE
			var sample: float = _get_sample(voice, t)
			voice.playback.push_frame(Vector2(sample, sample))
			voice.frame_pos += 1
		
		if voice.frame_pos >= voice.shot_end:
			voice.player.stop()
			voice.active = false
			voice.source_id = 0
	
	if not any_active:
		_has_active = false
		set_process(false)

# Find the first inactive voice in the pool
func _find_idle_voice() -> Voice:
	for voice in _voices:
		if not voice.active:
			return voice
	return null

# Generate a single audio sample at the given time.
# Mirrors the waveform generation logic from sound_synth.gd.
# Voice state (phase, frame_pos) is modified in-place.
func _get_sample(voice: Voice, t: float) -> float:
	var freq: float = voice.cached_freq
	
	# Frequency-modifying effects
	match voice.effect:
		Effect.WARBLE:
			freq += sin(TAU * 5.0 * t) * 30.0
		Effect.SWEEP_DOWN:
			freq *= maxf(0.1, 1.0 - t * 2.0)
	
	# Accumulate phase for continuous waveform
	voice.phase += freq / MIX_RATE
	
	var sample: float
	
	# Wave shape generation
	match voice.wave_shape:
		WaveShape.SINE:
			sample = sin(TAU * voice.phase)
		WaveShape.SQUARE:
			sample = sign(sin(TAU * voice.phase))
		WaveShape.SAWTOOTH:
			sample = 2.0 * (voice.phase - floor(voice.phase + 0.5))
		WaveShape.TRIANGLE:
			sample = 2.0 * abs(2.0 * (voice.phase - floor(voice.phase + 0.5))) - 1.0
		WaveShape.NOISE:
			var noise: float = randf() * 2.0 - 1.0
			var tone: float = sin(TAU * voice.phase)
			sample = lerp(tone, noise, 0.5)
	
	# Amplitude-modifying effects
	match voice.effect:
		Effect.TREMOLO:
			sample *= 0.5 + 0.5 * sin(TAU * 4.0 * t)
		Effect.DECAY:
			var progress: float = float(voice.frame_pos) / float(voice.shot_end)
			sample *= maxf(0.0, 1.0 - progress)
	
	return sample

# --- Voice Inner Class ---

class Voice:
	var player: AudioStreamPlayer2D
	var gen: AudioStreamGenerator
	var playback: AudioStreamGeneratorPlayback
	var active: bool = false
	var frame_pos: int = 0
	var shot_end: int = 0
	var phase: float = 0.0
	var cached_freq: float = 0.0
	var wave_shape: int = 0
	var effect: int = 0
	var source_id: int = 0