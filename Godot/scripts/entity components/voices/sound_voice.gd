# SoundVoice
# Plays a one-shot procedural sound or jingle via CDSoundBank
# Triggered by entity bus signal, supports filtering and exclusive playback

@tool
class_name SoundVoice extends CDEntityComponent

# --- exports ---

# sound definition resource (notes, wave shape, effect, volume)
@export var sound: CDSoundDef
# signal name that triggers playback
@export var trigger_signal: StringName = &""
# if set, only play when first signal arg matches this value
@export var filter_value: String = &""
# play immediately when entity initializes
@export var play_on_spawn: bool = false
# update positional audio based on entity world position
@export var positional: bool = true
# prevent overlapping instances of the same sound
@export var exclusive: bool = false
# suppress playback when game state is not PLAYING
@export var gameplay_only: bool = false

# --- preview ---

@export_group("Preview")
enum PreviewAction { NONE, PLAY, STOP }
# editor-only play/stop toggle, resets immediately after triggering
@export var preview_action: PreviewAction = PreviewAction.NONE:
	set(v):
		preview_action = PreviewAction.NONE
		if not Engine.is_editor_hint():
			return
		if v == PreviewAction.PLAY:
			_preview_play()
		elif v == PreviewAction.STOP:
			_preview_stop()

# --- state ---

# reference to the central sound bank
var _bank: CDSoundBank
# editor-only audio player for preview
var _preview_player: AudioStreamPlayer

# --- lifecycle ---

# find sound bank, connect trigger signal, optionally auto-play
func _on_initialize() -> void:
	_bank = game.find_child("CDSoundBank") as CDSoundBank
	
	# connect trigger listener
	if trigger_signal != &"":
		entity.ensure_signal(trigger_signal)
		entity.connect(trigger_signal, _on_trigger)
	
	# auto-play if configured
	if play_on_spawn:
		_try_play()

# --- signal handlers ---

# play sound when triggered, optionally filtering by signal arg
func _on_trigger(arg1 = null, _arg2 = null) -> void:
	if filter_value != &"":
		if str(arg1) != filter_value:
			return
	_try_play()

# --- playback ---

# attempt to play the sound through the bank
func _try_play() -> void:
	if sound == null or _bank == null:
		return
	if gameplay_only and game.current_state != CDEnums.GameState.PLAYING:
		return
	_bank.play_one_shot(sound, entity.global_position, positional,
		exclusive, entity.get_instance_id())

# --- cleanup ---

# disconnect trigger signal on entity deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if trigger_signal != &"" and entity.has_signal(trigger_signal):
		entity.disconnect(trigger_signal, _on_trigger)

# --- preview ---

# start editor preview playback
func _preview_play() -> void:
	if sound == null or sound.notes.is_empty():
		return
	
	_ensure_preview_player()
	_preview_player.play()
	call_deferred("_preview_fill")

# generate PCM audio frames for all notes in the sound definition
func _preview_fill() -> void:
	if not _preview_player or not _preview_player.playing:
		return
	var pb: AudioStreamGeneratorPlayback = _preview_player.get_stream_playback()
	if pb == null:
		return
	
	var phase: float = 0.0
	
	# render each note sequentially
	for cd_note: CDNote in sound.notes:
		var freq: float = CDUtilities.freq_from_note(cd_note.note)
		var total_frames: int = maxi(1, int(cd_note.duration * CDUtilities.MIX_RATE))
		
		# generate waveform samples for this note
		for i in total_frames:
			var t: float = float(i) / CDUtilities.MIX_RATE
			var mod_freq: float = CDUtilities.apply_freq_effect(freq, t, sound.effect)
			phase += mod_freq / CDUtilities.MIX_RATE
			var sample: float = CDUtilities.wave_sample(phase, sound.wave_shape)
			var note_progress: float = float(i) / float(total_frames)
			sample = CDUtilities.apply_amp_effect(sample, t, note_progress, sound.effect)
			pb.push_frame(Vector2(sample * sound.volume, sample * sound.volume))
		
		phase = 0.0

# stop editor preview playback
func _preview_stop() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()

# create or reuse the editor preview audio player, sizing buffer to sound duration
func _ensure_preview_player() -> void:
	# calculate total sound duration for buffer sizing
	var total_duration: float = 0.0
	if sound and not sound.notes.is_empty():
		for cd_note: CDNote in sound.notes:
			total_duration += cd_note.duration
	
	# reuse existing player, resizing buffer if needed
	if _preview_player and is_instance_valid(_preview_player):
		if _preview_player.playing:
			_preview_player.stop()
		@warning_ignore("confusable_local_declaration")
		var gen: AudioStreamGenerator = _preview_player.stream
		if total_duration + 0.1 > gen.buffer_length:
			gen.buffer_length = total_duration + 0.1
		return
	
	# create new preview player
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CDUtilities.MIX_RATE
	gen.buffer_length = maxf(1.0, total_duration + 0.1)
	_preview_player = AudioStreamPlayer.new()
	_preview_player.stream = gen
	_preview_player.volume_db = 0.0
	_preview_player.bus = &"Master"
	add_child(_preview_player)
