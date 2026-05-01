# Synthesized audio generator. Produces real-time waveforms (sine, square, sawtooth,
# triangle, noise) with optional effects (warble, tremolo, sweep, decay).
# Supports continuous playback or signal-triggered one-shots.
# Voice limiting mimics arcade hardware polyphony caps.

extends UniversalComponent2D

# Playback mode and wave configuration
@export var play_mode: PlayMode = PlayMode.CONTINUOUS
@export var wave_shape: WaveShape = WaveShape.SQUARE
@export var effect: Effect = Effect.NONE
@export var note: Semitone = Semitone.C4
@export var volume: float = 0.2
@export var duration: float = 0.15

# Signal-triggered playback configuration
@export var source_node: Node
@export var source_signal: String
@export var filter_value: String = ""

# Player configuration
@export var positional: bool = true
@export var exclusive: bool = false

# Enums
enum PlayMode { CONTINUOUS, ON_SIGNAL }
enum WaveShape { SINE, SQUARE, SAWTOOTH, TRIANGLE, NOISE }
enum Effect { NONE, WARBLE, TREMOLO, SWEEP_DOWN, DECAY }
enum Semitone {
	# Octave 3 (48-59)
	C3 = 48, CS3 = 49, D3 = 50, DS3 = 51, E3 = 52,
	F3 = 53, FS3 = 54, G3 = 55, GS3 = 56, A3 = 57, AS3 = 58, B3 = 59,
	# Octave 4 (60-71)
	C4 = 60, CS4 = 61, D4 = 62, DS4 = 63, E4 = 64,
	F4 = 65, FS4 = 66, G4 = 67, GS4 = 68, A4 = 69, AS4 = 70, B4 = 71,
	# Octave 5 (72-83)
	C5 = 72, CS5 = 73, D5 = 74, DS5 = 75, E5 = 76,
	F5 = 77, FS5 = 78, G5 = 79, GS5 = 80, A5 = 81, AS5 = 82, B5 = 83,
}

# Voice limiting (arcade hardware had 1-3 sound channels)
const MAX_VOICES: int = 6
const MAX_FILL_PER_FRAME: int = 256
static var _active_voices: int = 0
static var _continuous_registry: Dictionary = {}  # signature -> WeakRef to self
var _voice_active: bool = false
var _signature: String = ""

# Runtime state
var _stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _player: Node
var _frame_pos: int = 0
var _shot_end: int = 0
var _phase: float = 0.0

# Create the audio stream, player, and connect signal source if in ON_SIGNAL mode
func _ready() -> void:
	_stream = AudioStreamGenerator.new()
	_stream.mix_rate = 22050
	
	if positional:
		_player = AudioStreamPlayer2D.new()
	else:
		_player = AudioStreamPlayer.new()

	_player.stream = _stream
	_player.volume_db = linear_to_db(volume)
	add_child(_player)
	
	_signature = str(wave_shape) + "_" + str(effect) + "_" + str(note)
	
	# Start playback and fill initial buffer
	match play_mode:
		PlayMode.ON_SIGNAL:
			if source_node != null:
				source_node.connect(source_signal, _on_signal)
			_player.stop()
			set_process(false)
		PlayMode.CONTINUOUS:
			_try_claim_continuous()

# Try to register as the active CONTINUOUS synth for this signature
func _try_claim_continuous() -> void:
	var ref = _continuous_registry.get(_signature)
	if ref != null and ref.get_ref() != null:
		# Another synth already holds this slot — stay silent but keep processing
		_player.stop()
		_voice_active = false
		return
	# Slot is free — claim it
	if _active_voices >= MAX_VOICES:
		_player.stop()
		set_process(false)
		return
	_active_voices += 1
	_voice_active = true
	_continuous_registry[_signature] = weakref(self)
	_player.play()
	_playback = _player.get_stream_playback()

# Release voice when leaving the tree
func _exit_tree() -> void:
	if _voice_active:
		_active_voices -= 1
		_voice_active = false
	if play_mode == PlayMode.CONTINUOUS:
		var ref = _continuous_registry.get(_signature)
		if ref != null and ref.get_ref() == self:
			_continuous_registry.erase(_signature)

# Fill the audio buffer each frame; continuous or one-shot mode
func _process(_delta: float) -> void:
	match play_mode:
		PlayMode.CONTINUOUS:
			# If not active, check if the slot opened up
			if not _voice_active:
				var ref = _continuous_registry.get(_signature)
				if ref == null or ref.get_ref() == null:
					_try_claim_continuous()
				if not _voice_active:
					return
			var to_fill = mini(_playback.get_frames_available(), MAX_FILL_PER_FRAME)
			for i in to_fill:
				var t = float(_frame_pos) / _stream.mix_rate
				var sample = _get_sample(t)
				_playback.push_frame(Vector2(sample, sample))
				_frame_pos += 1
		
		PlayMode.ON_SIGNAL:
			# Fill remaining frames for the current one-shot
			var to_fill = mini(_playback.get_frames_available(), MAX_FILL_PER_FRAME)
			var remaining = _shot_end - _frame_pos
			var to_push = mini(mini(to_fill, remaining), MAX_FILL_PER_FRAME)
			for i in to_push:
				var t = float(_frame_pos) / _stream.mix_rate
				var sample = _get_sample(t)
				_playback.push_frame(Vector2(sample, sample))
				_frame_pos += 1
			if _frame_pos >= _shot_end:
				_player.stop()
				set_process(false)
				if _voice_active:
					_active_voices -= 1
					_voice_active = false

# Signal handler: play one-shot if filter matches (or no filter set)
func _on_signal(arg1 = "", _arg2 = null) -> void:
	if filter_value != "" and arg1 != filter_value:
		return
	play_one_shot()

# Start a one-shot playback from the beginning of the waveform
func play_one_shot() -> void:
	if exclusive and _player.playing:
		return
	if _active_voices >= MAX_VOICES:
		return
	_active_voices += 1
	_voice_active = true
	_frame_pos = 0
	_shot_end = int(duration * _stream.mix_rate)
	_phase = 0.0
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	
	# Fill as many frames as the buffer can hold
	var to_push = mini(mini(_playback.get_frames_available(), _shot_end), MAX_FILL_PER_FRAME)
	for i in to_push:
		var t = float(_frame_pos) / _stream.mix_rate
		var sample = _get_sample(t)
		_playback.push_frame(Vector2(sample, sample))
		_frame_pos += 1
	
	# Continue in _process if there are more frames to fill
	if _frame_pos >= _shot_end:
		set_process(false)
	else:
		set_process(true)

# --- Audio Generation ---

# Convert the semitone enum value to a frequency in Hz (A4 = 440Hz reference)
func _get_frequency() -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

# Generate a single audio sample at the given time, applying wave shape and effects
func _get_sample(t: float) -> float:
	var freq = _get_frequency()
	
	# Frequency-modifying effects
	match effect:
		Effect.WARBLE:
			freq += sin(TAU * 5.0 * t) * 30.0
		Effect.SWEEP_DOWN:
			freq *= max(0.1, 1.0 - t * 2.0)
	
	# Accumulate phase for continuous waveform
	_phase += freq / _stream.mix_rate
	
	var sample: float
	
	# Wave shape generation
	match wave_shape:
		WaveShape.SINE:
			sample = sin(TAU * _phase)
		WaveShape.SQUARE:
			sample = sign(sin(TAU * _phase))
		WaveShape.SAWTOOTH:
			sample = 2.0 * (_phase - floor(_phase + 0.5))
		WaveShape.TRIANGLE:
			sample = 2.0 * abs(2.0 * (_phase - floor(_phase + 0.5))) - 1.0
		WaveShape.NOISE:
			sample = randf() * 2.0 - 1.0
			var noise = randf() * 2.0 - 1.0
			var tone = sin(TAU * _phase)
			sample = lerp(tone, noise, 0.5)
	
	# Amplitude-modifying effects
	match effect:
		Effect.TREMOLO:
			sample *= 0.5 + 0.5 * sin(TAU * 4.0 * t)
		Effect.DECAY:
			var progress = float(_frame_pos) / float(_shot_end)
			sample *= max(0.0, 1.0 - progress)
	
	return sample
