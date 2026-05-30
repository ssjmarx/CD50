# SoundSpeaker
# Game-level one-shot or jingle synthesized sound triggered by game bus signal
# Delegates playback to CDSoundBank with optional gameplay-state gating

@tool
class_name SoundSpeaker extends CDGameComponent

# --- exports ---

# sound definition resource (notes, wave shape, effect, volume)
@export var sound: CDSoundDef
# game bus signal that triggers playback
@export var trigger_signal: StringName = &""
# only play during active gameplay state
@export var gameplay_only: bool = false

# editor preview controls
@export_group("Preview")
enum PreviewAction { NONE, PLAY, STOP }
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
# editor-only preview audio player
var _preview_player: AudioStreamPlayer

# --- lifecycle ---

# find sound bank and connect trigger signal
func _on_initialize() -> void:
	_bank = game.find_child("CDSoundBank") as CDSoundBank
	
	if trigger_signal != &"":
		game.bus_connect(trigger_signal, _on_trigger)

# disconnect trigger signal on removal
func _exit_tree() -> void:
	if trigger_signal != &"" and game:
		game.bus_disconnect(trigger_signal, _on_trigger)

# --- signal handlers ---

# play the sound via the bank when triggered
func _on_trigger(_arg1 = null, _arg2 = null) -> void:
	if sound == null or _bank == null:
		return
	# skip if gameplay-only and not currently playing
	if gameplay_only and game.current_state != CDEnums.GameState.PLAYING:
		return
	
	var sound_position: Vector2 = game.game_bounds.get_center() if game.game_bounds.has_area() else Vector2.ZERO
	_bank.play_one_shot(sound, sound_position, false, false, game.get_instance_id())

# --- editor preview ---

# start playing the sound in the editor
func _preview_play() -> void:
	if sound == null or sound.notes.is_empty():
		return
	
	_ensure_preview_player()
	_preview_player.play()
	call_deferred("_preview_fill")

# fill the preview audio buffer with the sound's note sequence
func _preview_fill() -> void:
	if not _preview_player or not _preview_player.playing:
		return
	var pb: AudioStreamGeneratorPlayback = _preview_player.get_stream_playback()
	if pb == null:
		return
	
	var phase: float = 0.0
	
	# synthesize each note in sequence
	for cd_note: CDNote in sound.notes:
		var freq: float = CDUtilities.freq_from_note(cd_note.note)
		var total_frames: int = maxi(1, int(cd_note.duration * CDUtilities.MIX_RATE))
		
		# generate samples for this note
		for i in total_frames:
			var t: float = float(i) / CDUtilities.MIX_RATE
			var mod_freq: float = CDUtilities.apply_freq_effect(freq, t, sound.effect)
			phase += mod_freq / CDUtilities.MIX_RATE
			var sample: float = CDUtilities.wave_sample(phase, sound.wave_shape)
			var note_progress: float = float(i) / float(total_frames)
			sample = CDUtilities.apply_amp_effect(sample, t, note_progress, sound.effect)
			pb.push_frame(Vector2(sample * sound.volume, sample * sound.volume))
		
		phase = 0.0

# stop the editor preview
func _preview_stop() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()

# create or resize the preview AudioStreamPlayer buffer
func _ensure_preview_player() -> void:
	# calculate total sound duration for buffer sizing
	var total_duration: float = 0.0
	if sound and not sound.notes.is_empty():
		for cd_note: CDNote in sound.notes:
			total_duration += cd_note.duration
	
	# reuse existing player if valid
	if _preview_player and is_instance_valid(_preview_player):
		if _preview_player.playing:
			_preview_player.stop()
		@warning_ignore("confusable_local_declaration")
		var gen: AudioStreamGenerator = _preview_player.stream
		if total_duration + 0.1 > gen.buffer_length:
			gen.buffer_length = total_duration + 0.1
		return
	
	# create new preview player with adequate buffer
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CDUtilities.MIX_RATE
	gen.buffer_length = maxf(1.0, total_duration + 0.1)
	_preview_player = AudioStreamPlayer.new()
	_preview_player.stream = gen
	_preview_player.volume_db = 0.0
	_preview_player.bus = &"Master"
	add_child(_preview_player)
