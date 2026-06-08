## CDSoundBank
## Centralized procedural audio engine for V2
## Generates all sound effects at runtime via AudioStreamGenerator — no audio files needed

class_name CDSoundBank extends CDGameComponent

## --- Constants ---

const MIX_RATE: int = 11025
const MAX_CONTINUOUS: int = 4
const MAX_FILL_PER_FRAME: int = 256
const MAX_INITIAL_FILL: int = 128
const POSITIONAL_DISTANCE: float = 2000.0
const GLOBAL_DISTANCE: float = 2000000.0

## --- Exports ---

## max simultaneous one-shot voices (set lower for arcade authenticity, e.g. 3 for Galaga)
@export var max_channels: int = 8

## --- Voice Pools ---

## one-shot voice pool (pew, boom, bounce)
var _voices: Array = []
## continuous voice pool (engine hum, alarm)
var _continuous_pool: Array = []
## active one-shot voices keyed by CDSoundDef instance id (sound dedup)
var _sound_registry: Dictionary = {}  # sound_def_id : Voice
## active continuous voices keyed by signature string
var _continuous_registry: Dictionary = {}  # signature : Voice
## tracks whether any voice is active (controls process flag)
var _has_active: bool = false

## --- Setup ---

## create voice pools with AudioStreamPlayer2D nodes
func _on_initialize() -> void:
	set_process(false)

	## create one-shot voice pool
	for i in max_channels:
		var voice := Voice.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		var player := AudioStreamPlayer2D.new()
		player.stream = gen
		player.bus = &"CD_Audio"
		add_child(player)
		voice.player = player
		voice.gen = gen
		_voices.append(voice)

	## create continuous voice pool
	for i in MAX_CONTINUOUS:
		var voice := Voice.new()
		voice.continuous = true
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		var player := AudioStreamPlayer2D.new()
		player.stream = gen
		player.bus = &"CD_Audio"
		add_child(player)
		voice.player = player
		voice.gen = gen
		_continuous_pool.append(voice)

## --- Fill Loop ---

## push audio frames to all active voices (runs only when _has_active is true)
func _process(_delta: float) -> void:
	var any_active := false

	## fill continuous voices (looped audio)
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

	## fill one-shot voices (finite duration)
	for voice in _voices:
		if not voice.active:
			continue
		any_active = true

		## drain: let the buffer finish playing after generation completes
		if voice.draining:
			voice.drain_remaining -= _delta
			if voice.drain_remaining <= 0.0:
				_release_voice(voice)
			continue

		## push frames up to end of current note
		var to_fill: int = mini(voice.playback.get_frames_available(), MAX_FILL_PER_FRAME)
		var remaining: int = voice.shot_end - voice.frame_pos
		var to_push: int = mini(to_fill, remaining)
		for i in to_push:
			var t: float = float(voice.frame_pos - voice.note_frame_start) / MIX_RATE
			var sample: float = _get_sample(voice, t)
			voice.playback.push_frame(Vector2(sample, sample))
			voice.frame_pos += 1

		if voice.frame_pos >= voice.shot_end:
			if _advance_jingle(voice):
				continue

			## generation complete — enter drain mode to let buffer finish playing
			_sound_registry.erase(voice.sound_id)
			voice.draining = true
			voice.drain_remaining = voice.gen.buffer_length
			voice.sound_id = 0
			voice.source_id = 0
			voice.notes = []
			voice.note_index = 0

	if not any_active:
		_has_active = false
		set_process(false)

## lazily enable processing when first voice becomes active
func _ensure_process() -> void:
	if not _has_active:
		_has_active = true
		set_process(true)

## --- One-Shot API ---

## play a single sound effect at a position
func play_one_shot(def: CDSoundDef, sound_position: Vector2, positional: bool,
		exclusive: bool, caller_id: int) -> bool:

	if def.notes.is_empty():
		return false

	var sound_id: int = def.get_instance_id()

	## --- Sound-level dedup ---
	## if this exact CDSoundDef is already playing, apply arcade-authentic behavior
	if _sound_registry.has(sound_id):
		if exclusive:
			## exclusive: skip — only one channel per sound type
			return false
		else:
			## non-exclusive: restart the sound from the beginning
			## (arcade hardware would overlap; we restart which creates
			## the same stuttering buzz effect for rapid fire)
			var existing: Voice = _sound_registry[sound_id]
			_restart_voice(existing, def, sound_position, positional)
			return true

	## --- Allocate a new voice ---
	var voice: Voice = _find_idle_voice()
	if voice == null:
		return false

	## register in sound registry before configuring
	_sound_registry[sound_id] = voice

	## configure voice state from sound definition
	voice.active = true
	voice.sound_id = sound_id
	voice.source_id = caller_id
	voice.wave_shape = def.wave_shape
	voice.effect = def.effect
	voice.frame_pos = 0
	voice.phase = 0.0
	voice.volume = def.volume

	## initialize reverb buffer if needed
	if def.effect == CDEnums.Effect.REVERB:
		_init_reverb_buf(voice)
	else:
		voice.reverb_buf.clear()
		voice.reverb_size = 0

	## jingle sequencing: start at first note
	voice.note_index = 0
	voice.notes = def.notes
	voice.note_frame_start = 0
	var first_note: CDNote = def.notes[0]
	voice.shot_end = maxi(1, int(first_note.duration * MIX_RATE))
	voice.cached_freq = CDUtilities.freq_from_note(first_note.note)

	## configure player position and distance attenuation
	voice.player.volume_db = linear_to_db(def.volume)
	voice.player.global_position = sound_position
	if positional:
		voice.player.max_distance = POSITIONAL_DISTANCE
	else:
		voice.player.max_distance = GLOBAL_DISTANCE

	if not voice.player.playing:
		voice.player.play()
	voice.playback = voice.player.get_stream_playback()

	## initial fill to prevent audio gaps
	_fill_voice_initial(voice)

	_ensure_process()
	return true

## restart a voice from the beginning (arcade-authentic overlap for non-exclusive sounds)
func _restart_voice(voice: Voice, def: CDSoundDef, sound_position: Vector2,
		positional: bool) -> void:
	## reset playback state to beginning of jingle
	voice.frame_pos = 0
	voice.phase = 0.0
	voice.note_index = 0
	voice.note_frame_start = 0
	voice.notes = def.notes
	voice.wave_shape = def.wave_shape
	voice.effect = def.effect
	voice.volume = def.volume
	var first_note: CDNote = def.notes[0]
	voice.shot_end = maxi(1, int(first_note.duration * MIX_RATE))
	voice.cached_freq = CDUtilities.freq_from_note(first_note.note)

	## re-initialize reverb buffer if needed
	if def.effect == CDEnums.Effect.REVERB:
		_init_reverb_buf(voice)

	## update position
	voice.player.global_position = sound_position
	if positional:
		voice.player.max_distance = POSITIONAL_DISTANCE
	else:
		voice.player.max_distance = GLOBAL_DISTANCE

	## fill from restart point
	_fill_voice_initial(voice)

## push initial audio frames to prevent gaps on new/restarted voices
func _fill_voice_initial(voice: Voice) -> void:
	var available: int = voice.playback.get_frames_available()
	var remaining: int = voice.shot_end - voice.frame_pos
	var to_push: int = mini(mini(available, remaining), MAX_INITIAL_FILL)
	for i in to_push:
		var t: float = float(voice.frame_pos - voice.note_frame_start) / MIX_RATE
		var sample: float = _get_sample(voice, t)
		voice.playback.push_frame(Vector2(sample, sample))
		voice.frame_pos += 1

## advance to next note in a jingle sequence
func _advance_jingle(voice: Voice) -> bool:
	voice.note_index += 1
	if voice.note_index >= voice.notes.size():
		return false

	## configure next note timing and frequency
	var next_note: CDNote = voice.notes[voice.note_index]
	voice.note_frame_start = voice.frame_pos
	var note_frames: int = maxi(1, int(next_note.duration * MIX_RATE))
	voice.shot_end = voice.frame_pos + note_frames

	## save previous frequency before updating
	var prev_freq: float = voice.cached_freq
	voice.cached_freq = CDUtilities.freq_from_note(next_note.note)

	## glide: smoothly transition from previous frequency
	if next_note.glide:
		voice.is_gliding = true
		voice.glide_start_freq = prev_freq
		voice.glide_target_freq = voice.cached_freq
		voice.glide_frames = note_frames
		## DON'T reset phase — continuous accumulation for smooth glide
	else:
		voice.is_gliding = false
		voice.phase = 0.0

	voice.player.volume_db = linear_to_db(voice.volume)
	return true

## --- Continuous API ---

## start a looped sound (ref-counted for multiple sources sharing one voice)
func start_continuous(signature: String, wave_shape: int, effect: int,
		note: int, volume: float, source_id: int,
		sound_position: Vector2, positional: bool) -> bool:

	## dedup: if already playing, increment ref count
	if _continuous_registry.has(signature):
		var existing: Voice = _continuous_registry[signature]
		existing.ref_count += 1
		existing.source_ids[source_id] = sound_position

		if existing.ref_count > 1:
			existing.player.max_distance = GLOBAL_DISTANCE
		return true

	var voice: Voice = _find_idle_continuous_voice()
	if voice == null:
		return false

	## configure voice for continuous playback
	voice.active = true
	voice.ref_count = 1
	voice.source_ids = {source_id: sound_position}
	voice.wave_shape = wave_shape
	voice.effect = effect
	voice.frame_pos = 0
	voice.phase = 0.0
	voice.shot_end = 0
	voice.cached_freq = CDUtilities.freq_from_note(note)
	voice.player.volume_db = linear_to_db(volume)
	voice.player.global_position = sound_position
	voice.player.max_distance = POSITIONAL_DISTANCE if positional else GLOBAL_DISTANCE
	voice.player.play()
	voice.playback = voice.player.get_stream_playback()
	_continuous_registry[signature] = voice
	_ensure_process()
	return true

## stop a source's contribution to a continuous voice (decrements ref count)
func stop_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.source_ids.erase(source_id)
	voice.ref_count -= 1

	## no more sources — fully stop the voice
	if voice.ref_count <= 0:
		voice.player.stop()
		voice.active = false
		voice.ref_count = 0
		voice.source_ids.clear()
		voice.paused_sources.clear()
		_continuous_registry.erase(signature)
	## back to single source — restore positional audio
	elif voice.ref_count == 1:
		var remaining_pos: Vector2 = voice.source_ids.values()[0]
		voice.player.global_position = remaining_pos
		voice.player.max_distance = POSITIONAL_DISTANCE

## pause a source's continuous sound (voice pauses if all sources are paused)
func pause_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.paused_sources[source_id] = true
	if voice.player.playing:
		voice.player.stop()

## resume a source's continuous sound (voice resumes if no sources are paused)
func resume_continuous(signature: String, source_id: int) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.paused_sources.erase(source_id)
	if voice.paused_sources.is_empty() and not voice.player.playing and voice.active:
		voice.player.play()
		voice.playback = voice.player.get_stream_playback()

## update position for a source contributing to a continuous voice
func update_continuous_position(signature: String, source_id: int, sound_position: Vector2) -> void:
	if not _continuous_registry.has(signature):
		return
	var voice: Voice = _continuous_registry[signature]
	voice.source_ids[source_id] = sound_position
	if voice.ref_count == 1:
		voice.player.global_position = sound_position

## --- Helpers ---

## release a voice — stop playback and clear all state
func _release_voice(voice: Voice) -> void:
	voice.player.stop()
	voice.active = false
	voice.draining = false
	voice.drain_remaining = 0.0
	voice.sound_id = 0
	voice.source_id = 0
	voice.notes = []
	voice.note_index = 0

## find an idle one-shot voice (will reclaim a draining voice if all are busy)
func _find_idle_voice() -> Voice:
	for voice in _voices:
		if not voice.active:
			return voice
	## all voices busy — reclaim a draining voice rather than drop the sound
	for voice in _voices:
		if voice.draining:
			_release_voice(voice)
			return voice
	return null

## find an idle continuous voice
func _find_idle_continuous_voice() -> Voice:
	for voice in _continuous_pool:
		if not voice.active:
			return voice
	return null

## initialize the per-voice reverb delay buffer
func _init_reverb_buf(voice: Voice) -> void:
	var size: int = REVERB_DELAY_3 + 1
	if voice.reverb_size != size:
		voice.reverb_buf = PackedFloat32Array()
		voice.reverb_buf.resize(size)
		voice.reverb_buf.fill(0.0)
		voice.reverb_size = size
		voice.reverb_pos = 0
	else:
		voice.reverb_buf.fill(0.0)
		voice.reverb_pos = 0

## reverb delay lines in frames (at 11025 Hz mix rate)
const REVERB_DELAY_1: int = 1102    ## 100ms
const REVERB_DELAY_2: int = 1654    ## 150ms
const REVERB_DELAY_3: int = 2205    ## 200ms
const REVERB_FEEDBACK: float = 0.3
const REVERB_MIX: float = 0.4

## generate a single audio sample for a voice at time t
func _get_sample(voice: Voice, t: float) -> float:
	## glide: interpolate frequency from start to target over note duration
	var base_freq: float = voice.cached_freq
	if voice.is_gliding and voice.glide_frames > 0:
		var elapsed: int = voice.frame_pos - voice.note_frame_start
		var progress: float = clampf(float(elapsed) / float(voice.glide_frames), 0.0, 1.0)
		base_freq = lerpf(voice.glide_start_freq, voice.glide_target_freq, progress)

	var freq: float = CDUtilities.apply_freq_effect(base_freq, t, voice.effect)
	voice.phase += freq / MIX_RATE
	var sample: float = CDUtilities.wave_sample(voice.phase, voice.wave_shape)

	## calculate note progress for amplitude envelope
	var note_progress: float = 0.0
	if voice.shot_end > 0:
		var note_duration: int = voice.shot_end - voice.note_frame_start
		if note_duration > 0:
			note_progress = float(voice.frame_pos - voice.note_frame_start) / float(note_duration)

	sample = CDUtilities.apply_amp_effect(sample, t, note_progress, voice.effect)

	## apply reverb effect via delay buffer
	if voice.effect == CDEnums.Effect.REVERB and voice.reverb_buf.size() > 0:
		var buf: PackedFloat32Array = voice.reverb_buf
		var pos: int = voice.reverb_pos
		## sum output from three delay taps
		var wet: float = 0.0
		var d1: int = (pos - REVERB_DELAY_1 + voice.reverb_size) % voice.reverb_size
		var d2: int = (pos - REVERB_DELAY_2 + voice.reverb_size) % voice.reverb_size
		var d3: int = (pos - REVERB_DELAY_3 + voice.reverb_size) % voice.reverb_size
		wet = buf[d1] * 0.5 + buf[d2] * 0.3 + buf[d3] * 0.2
		## write input + feedback into buffer
		buf[pos] = sample + wet * REVERB_FEEDBACK
		voice.reverb_pos = (pos + 1) % voice.reverb_size
		## mix dry + wet
		sample = sample * (1.0 - REVERB_MIX) + wet * REVERB_MIX

	return sample

## --- Voice Inner Class ---

## holds per-voice state for an AudioStreamGenerator
class Voice:
	var player: Node
	var gen: AudioStreamGenerator
	var playback: AudioStreamGeneratorPlayback
	var active: bool = false
	var frame_pos: int = 0
	var shot_end: int = 0
	var phase: float = 0.0
	var cached_freq: float = 0.0
	var wave_shape: int = 0
	var effect: int = 0
	var volume: float = 0.2
	var sound_id: int = 0
	var source_id: int = 0

	## jingle sequencing state
	var note_index: int = 0
	var notes: Array = []
	var note_frame_start: int = 0

	## glide/portamento state
	var is_gliding: bool = false
	var glide_start_freq: float = 0.0
	var glide_target_freq: float = 0.0
	var glide_frames: int = 0

	## drain state (let buffer finish playing after generation completes)
	var draining: bool = false
	var drain_remaining: float = 0.0

	## reverb effect state (per-voice delay buffer)
	var reverb_buf: PackedFloat32Array = []
	var reverb_pos: int = 0
	var reverb_size: int = 0

	## continuous voice state
	var continuous: bool = false
	var ref_count: int = 0
	var source_ids: Dictionary = {}  # source_id : position
	var paused_sources: Dictionary = {}  # source_id : true
