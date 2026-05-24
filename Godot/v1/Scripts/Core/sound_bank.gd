# Centralized audio pool for one-shot and continuous synthesized sounds.
# Pre-warms fixed pools of audio player + generator pairs to eliminate
# per-entity node creation/destruction overhead.
#
# SoundSynth routes ALL playback through this autoload:
# - ON_SIGNAL mode: one-shot sounds via play()
# - CONTINUOUS mode: persistent sounds via start_continuous()/stop_continuous()
#
# The centralized _process loop fills ALL active voices in one pass.
# Players live in the root scene tree, ensuring sounds are audible
# inside SubViewports (arcade mode).

extends Node

# Audio constants
const MIX_RATE: int = 11025
const MAX_VOICES: int = 8
const MAX_CONTINUOUS: int = 4
const MAX_FILL_PER_FRAME: int = 256
const MAX_INITIAL_FILL: int = 128

# Wave shape and effect enums (mirrored from SoundSynth)
enum WaveShape { SINE, SQUARE, SAWTOOTH, TRIANGLE, NOISE }
enum Effect { NONE, WARBLE, TREMOLO, SWEEP_DOWN, DECAY }

# One-shot voice pool
var _voices: Array = []
# Continuous voice pool
var _continuous_pool: Array = []
var _continuous_registry: Dictionary = {}  # signature -> Voice
var _has_active: bool = false

# Pre-warm both voice pools with persistent nodes.
# Created once and reused forever — no per-sound node churn.
func _ready() -> void:
	set_process(false)
	# One-shot pool (AudioStreamPlayer2D for positional audio)
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
	# Continuous pool (AudioStreamPlayer, non-positional, root-level)
	for i in MAX_CONTINUOUS:
		var voice := Voice.new()
		voice.continuous = true
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		var player := AudioStreamPlayer.new()
		player.stream = gen
		add_child(player)
		voice.player = player
		voice.gen = gen
		_continuous_pool.append(voice)

# --- One-Shot API ---

# Play a one-shot synthesized sound from the pool.
# Returns true if a voice was claimed, false if all voices busy.
func play(wave_shape: int, effect: int, note: int, volume: float,
		duration: float, position: Vector2, positional: bool,
		exclusive: bool, source_id: int) -> bool:
	
	# Exclusive: skip if this source already has an active voice
	if exclusive:
		for v in _voices:
			if v.active and v.source_id == source_id:
				return false
	
	# Check if this source already has an active voice — restart it
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
	var p2d := voice.player as AudioStreamPlayer2D
	if p2d:
		if positional:
			p2d.global_position = position
			p2d.max_distance = 2000.0
		else:
			p2d.global_position = Vector2.ZERO
			p2d.max_distance = 2000000.0
	
	if not voice.player.playing:
		voice.player.play()
	voice.playback = voice.player.get_stream_playback()
	
	# Initial fill — capped to prevent audio-gen spikes during collision callbacks
	var available: int = voice.playback.get_frames_available()
	var to_push: int = mini(mini(available, voice.shot_end), MAX_INITIAL_FILL)
	for i in to_push:
		var t: float = float(voice.frame_pos) / MIX_RATE
		var sample: float = _get_sample(voice, t)
		voice.playback.push_frame(Vector2(sample, sample))
		voice.frame_pos += 1
	
	_ensure_process()
	return true

# --- Continuous API ---

# Start or join a continuous voice for the given signature.
# Multiple synths with the same signature share one voice (dedup).
# Returns true if a voice was claimed, false if all voices busy.
func start_continuous(signature: String, wave_shape: int, effect: int,
		note: int, volume: float, source_id: int) -> bool:
	# If signature already active, increment ref count (dedup)
	if _continuous_registry.has(signature):
		var existing: Voice = _continuous_registry[signature]
		existing.ref_count += 1
		existing.source_ids[source_id] = true
		return true
	# Find idle continuous voice
	var voice: Voice = _find_idle_continuous_voice()
	if voice == null:
		return false
	# Configure
	voice.active = true
	voice.ref_count = 1
	voice.source_ids = {source_id: true}
	voice.wave_shape = wave_shape
	voice.effect = effect
	voice.frame_pos = 0
	voice.phase = 0.0
	voice.shot_end = 0  # 0 = continuous (no end)
	voice.cached_freq = 440.0 * pow(2.0, (note - 69) / 12.0)
	voice.player.volume_db = linear_to_db(volume)
	voice.player.play()
	voice.playback = voice.player.get_stream_playback()
	_continuous_registry[signature] = voice
	_ensure_process()
	return true

# Release a continuous voice. Stops the voice when all sources have released.
func stop_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.source_ids.erase(source_id)
	voice.ref_count -= 1
	if voice.ref_count <= 0:
		voice.player.stop()
		voice.active = false
		voice.ref_count = 0
		voice.source_ids.clear()
		voice.paused_sources.clear()
		_continuous_registry.erase(signature)

# Pause a continuous voice for a specific source.
# Voice is paused if ANY source requests pause.
func pause_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.paused_sources[source_id] = true
	if voice.player.playing:
		voice.player.stop()

# Resume a continuous voice for a specific source.
# Voice resumes only when ALL sources have resumed.
func resume_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.paused_sources.erase(source_id)
	if voice.paused_sources.is_empty() and not voice.player.playing and voice.active:
		voice.player.play()
		voice.playback = voice.player.get_stream_playback()

# --- Centralized Fill Loop ---

func _ensure_process() -> void:
	if not _has_active:
		_has_active = true
		set_process(true)

# Processes all active voices (continuous + one-shot) in one pass.
# Only runs when there are active voices (enabled/disabled dynamically).
func _process(_delta: float) -> void:
	var any_active := false
	
	# Fill continuous voices
	for sig in _continuous_registry:
		var voice: Voice = _continuous_registry[sig]
		if not voice.active:
			continue
		if not voice.paused_sources.is_empty():
			continue
		any_active = true
		var to_fill: int = mini(voice.playback.get_frames_available(), MAX_FILL_PER_FRAME)
		for i in to_fill:
			var t: float = float(voice.frame_pos) / MIX_RATE
			var sample: float = _get_sample(voice, t)
			voice.playback.push_frame(Vector2(sample, sample))
			voice.frame_pos += 1
	
	# Fill one-shot voices
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

# --- Helpers ---

func _find_idle_voice() -> Voice:
	for voice in _voices:
		if not voice.active:
			return voice
	return null

func _find_idle_continuous_voice() -> Voice:
	for voice in _continuous_pool:
		if not voice.active:
			return voice
	return null

# Generate a single audio sample at the given time.
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
			if voice.shot_end > 0:
				var progress: float = float(voice.frame_pos) / float(voice.shot_end)
				sample *= maxf(0.0, 1.0 - progress)
	
	return sample

# --- Voice Inner Class ---

class Voice:
	var player: Node  # AudioStreamPlayer (continuous) or AudioStreamPlayer2D (one-shot)
	var gen: AudioStreamGenerator
	var playback: AudioStreamGeneratorPlayback
	var active: bool = false
	var frame_pos: int = 0
	var shot_end: int = 0  # 0 = continuous (no end)
	var phase: float = 0.0
	var cached_freq: float = 0.0
	var wave_shape: int = 0
	var effect: int = 0
	# One-shot fields
	var source_id: int = 0
	# Continuous fields
	var continuous: bool = false
	var ref_count: int = 0
	var source_ids: Dictionary = {}  # source_id -> true
	var paused_sources: Dictionary = {}  # source_id -> true