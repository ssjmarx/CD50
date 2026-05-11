# Synthesized audio generator. Produces real-time waveforms (sine, square, sawtooth,
# triangle, noise) with optional effects (warble, tremolo, sweep, decay).
# Supports continuous playback or signal-triggered one-shots.
# Voice limiting mimics arcade hardware polyphony caps.
# Editor preview: check the "Preview Sound" toggle in the inspector to hear it.

@tool
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
@export var gameplay_only: bool = false

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
const MIX_RATE: int = 11025
const MAX_VOICES: int = 8
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
var _cached_freq: float = 0.0
var _blocking_node: Node = null

# Initial fill cap for play_one_shot — limits samples generated during collision
# callbacks to prevent audio-gen spikes. Remaining samples fill via _process.
const MAX_INITIAL_FILL: int = 128

# Editor preview state
var _preview_player: AudioStreamPlayer = null

# --- Property List for Editor Preview ---

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({
		"name": "preview_sound",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_EDITOR,
		"hint_string": "Preview Sound"
	})
	return props

func _set(property: StringName, value: Variant) -> bool:
	if property == "preview_sound" and value == true:
		_editor_preview()
		return true
	return false

func _get(property: StringName) -> Variant:
	if property == "preview_sound":
		return false  # Always unchecked
	return null

# Play a preview of this sound in the editor
func _editor_preview() -> void:
	_update_cached_freq()
	# Clean up any existing preview
	if _preview_player and is_instance_valid(_preview_player):
		_preview_player.queue_free()
		_preview_player = null
	
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	_preview_player = AudioStreamPlayer.new()
	_preview_player.stream = stream
	_preview_player.volume_db = linear_to_db(volume)
	add_child(_preview_player)
	_preview_player.play()
	var playback = _preview_player.get_stream_playback()
	
	# Generate the full waveform and fill the buffer
	var total_frames = int(duration * MIX_RATE)
	_shot_end = total_frames
	_frame_pos = 0
	_phase = 0.0
	
	# Fill as much as the buffer allows, then continue in _process
	var to_push = mini(mini(playback.get_frames_available(), total_frames), MAX_FILL_PER_FRAME)
	for i in to_push:
		var t = float(_frame_pos) / MIX_RATE
		var sample = _get_sample(t)
		playback.push_frame(Vector2(sample, sample))
		_frame_pos += 1
	
	if _frame_pos < total_frames:
		set_process(true)
	else:
		# Schedule cleanup after playback finishes
		get_tree().create_timer(duration + 0.05).timeout.connect(func():
			if _preview_player and is_instance_valid(_preview_player):
				_preview_player.queue_free()
				_preview_player = null
		)

# Create the audio stream, player, and connect signal source if in ON_SIGNAL mode
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_stream = AudioStreamGenerator.new()
	_stream.mix_rate = MIX_RATE
	
	if positional:
		_player = AudioStreamPlayer2D.new()
	else:
		_player = AudioStreamPlayer.new()

	_player.stream = _stream
	_player.volume_db = linear_to_db(volume)
	add_child(_player)
	
	_signature = str(wave_shape) + "_" + str(effect) + "_" + str(note)
	_update_cached_freq()
	
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
		# Another synth already holds this slot — connect to its tree_exiting signal
		# instead of polling every frame
		_player.stop()
		_voice_active = false
		var blocking = ref.get_ref() as Node
		if blocking and not blocking.tree_exiting.is_connected(_on_slot_freed):
			blocking.tree_exiting.connect(_on_slot_freed)
			_blocking_node = blocking
		set_process(false)
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
	# Clean up: disconnect from blocking synth if we were waiting
	if _blocking_node and is_instance_valid(_blocking_node):
		if _blocking_node.tree_exiting.is_connected(_on_slot_freed):
			_blocking_node.tree_exiting.disconnect(_on_slot_freed)
		_blocking_node = null
	if _voice_active:
		_active_voices -= 1
		_voice_active = false
	if play_mode == PlayMode.CONTINUOUS:
		var ref = _continuous_registry.get(_signature)
		if ref != null and ref.get_ref() == self:
			_continuous_registry.erase(_signature)

# Fill the audio buffer each frame; continuous or one-shot mode
func _process(_delta: float) -> void:
	# Editor preview: continue filling multi-frame previews
	if Engine.is_editor_hint():
		_process_editor_preview()
		return
	
	match play_mode:
		PlayMode.CONTINUOUS:
			if gameplay_only and game != null and game.current_state != CommonEnums.State.PLAYING:
				if _player.playing:
					_player.stop()
				return
			# If stopped (was gated), restart when back to PLAYING
			if not _player.playing and _voice_active:
				_player.play()
				_playback = _player.get_stream_playback()
			# If not active, wait for signal-based slot notification
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
	if filter_value != "" and str(arg1) != filter_value:
		return
	play_one_shot()

# Start a one-shot playback from the beginning of the waveform
func play_one_shot() -> void:
	if exclusive and _player.playing:
		return
	if _active_voices >= MAX_VOICES:
		return
	if gameplay_only and game != null and game.current_state != CommonEnums.State.PLAYING:
		return
	
	# Only claim a new voice slot if we don't already have one
	if not _voice_active:
		_active_voices += 1
		_voice_active = true
	
	_frame_pos = 0
	_shot_end = int(duration * _stream.mix_rate)
	_phase = 0.0
	_update_cached_freq()
	
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	
	# Cap initial fill to limit audio-gen work during collision callbacks.
	# Remaining samples are generated in _process over subsequent frames.
	var to_push = mini(mini(_playback.get_frames_available(), _shot_end), MAX_INITIAL_FILL)
	for i in to_push:
		var t = float(_frame_pos) / _stream.mix_rate
		var sample = _get_sample(t)
		_playback.push_frame(Vector2(sample, sample))
		_frame_pos += 1
	
	# Continue in _process if there are more frames to fill
	if _frame_pos < _shot_end:
		set_process(true)

# --- Audio Generation ---

# Pre-compute frequency from current note (A4 = 440Hz reference).
# Called once per note change instead of per-sample to avoid pow() in the hot loop.
func _update_cached_freq() -> void:
	_cached_freq = 440.0 * pow(2.0, (note - 69) / 12.0)

# Signal handler: a blocking continuous synth is exiting the tree.
# Clean up its registry entry so we can claim the freed slot.
func _on_slot_freed() -> void:
	if _blocking_node and is_instance_valid(_blocking_node):
		var ref = _continuous_registry.get(_signature)
		if ref != null and ref.get_ref() == _blocking_node:
			_continuous_registry.erase(_signature)
		_blocking_node = null
	_try_claim_continuous()
	if _voice_active:
		set_process(true)

# Generate a single audio sample at the given time, applying wave shape and effects
func _get_sample(t: float) -> float:
	var freq = _cached_freq
	
	# Frequency-modifying effects
	match effect:
		Effect.WARBLE:
			freq += sin(TAU * 5.0 * t) * 30.0
		Effect.SWEEP_DOWN:
			freq *= max(0.1, 1.0 - t * 2.0)
	
	# Accumulate phase for continuous waveform
	_phase += freq / MIX_RATE
	
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

# Continue filling editor preview buffer over multiple frames
func _process_editor_preview() -> void:
	if not _preview_player or not is_instance_valid(_preview_player) or not _preview_player.playing:
		if _preview_player and is_instance_valid(_preview_player):
			_preview_player.queue_free()
			_preview_player = null
		set_process(false)
		return
	
	var playback = _preview_player.get_stream_playback()
	var to_fill = mini(playback.get_frames_available(), MAX_FILL_PER_FRAME)
	var remaining = _shot_end - _frame_pos
	var to_push = mini(to_fill, remaining)
	
	for i in to_push:
		var t = float(_frame_pos) / MIX_RATE
		var sample = _get_sample(t)
		playback.push_frame(Vector2(sample, sample))
		_frame_pos += 1
	
	if _frame_pos >= _shot_end:
		# All frames pushed — schedule cleanup and stop processing
		var wait = duration + 0.05
		get_tree().create_timer(wait).timeout.connect(func():
			if _preview_player and is_instance_valid(_preview_player):
				_preview_player.queue_free()
				_preview_player = null
		)
		set_process(false)
