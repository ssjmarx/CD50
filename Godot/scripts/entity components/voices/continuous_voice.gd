## ContinuousVoice
## Plays an ongoing procedural oscillator tone via CDSoundBank
## Multiple entities sharing the same signature blend into one audio stream

@tool
class_name ContinuousVoice extends CDEntityComponent

## --- exports ---

## oscillator waveform shape
@export var wave_shape: CDEnums.WaveShape = CDEnums.WaveShape.SQUARE
## frequency/amplitude modulation effect
@export var effect: CDEnums.Effect = CDEnums.Effect.NONE
## base pitch as a semitone constant
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4
## output volume (0.0 to 1.0)
@export var volume: float = 0.2
## signal name that starts playback
@export var start_signal: StringName = &""
## signal name that stops playback
@export var stop_signal: StringName = &""
## pause sound when game state is not PLAYING
@export var gameplay_only: bool = false
## register with sound bank immediately on spawn
@export var start_on_spawn: bool = false
## deregister from sound bank when entity deactivates
@export var stop_on_deactivate: bool = true
## update positional audio based on entity world position
@export var positional: bool = true

## --- preview ---

@export_group("Preview")
enum PreviewAction { NONE, PLAY, STOP }
## editor-only play/stop toggle, resets immediately after triggering
@export var preview_action: PreviewAction = PreviewAction.NONE:
	set(v):
		preview_action = PreviewAction.NONE
		if not Engine.is_editor_hint():
			return
		if v == PreviewAction.PLAY:
			_preview_play()
		elif v == PreviewAction.STOP:
			_preview_stop()

## duration of the preview tone in seconds
@export var preview_duration: float = 0.5

## --- state ---

## reference to the central sound bank
var _bank: CDSoundBank
## unique identifier for this sound combo: "{wave}_{effect}_{note}"
var _signature: String
## whether this voice is currently registered with the bank
var _is_registered: bool = false
## editor-only audio player for preview
var _preview_player: AudioStreamPlayer

## --- lifecycle ---

## use the game-level sound_bank ref (resolved by CDGame), connect signals, auto-start
func _on_initialize() -> void:
	_bank = game.sound_bank
	_signature = _build_signature()
	
	if start_signal != &"":
		entity.ensure_signal(start_signal)
		entity.connect(start_signal, _on_start)
	
	if stop_signal != &"":
		entity.ensure_signal(stop_signal)
		entity.connect(stop_signal, _on_stop)
	
	if start_on_spawn:
		_register()
	
	set_physics_process(true)

## --- helpers ---

## build a signature string identifying this sound combo
func _build_signature() -> String:
	return "%d_%d_%d" % [wave_shape, effect, note]

## --- signal handlers ---

## start playback
func _on_start() -> void:
	_register()

## stop playback
func _on_stop() -> void:
	_deregister()

## --- processing ---

## update positional audio and respect gameplay-only pause
func _physics_process(_delta: float) -> void:
	if not _is_registered:
		return
	
	## pause/resume based on game state
	if gameplay_only:
		if game.current_state != CDEnums.GameState.PLAYING:
			_bank.pause_continuous(_signature, entity.get_instance_id())
			return
		else:
			_bank.resume_continuous(_signature, entity.get_instance_id())
	
	if positional:
		_bank.update_continuous_position(_signature, entity.get_instance_id(), entity.global_position)

## --- bank registration ---

## register this voice with the sound bank for playback
func _register() -> void:
	if _bank == null or _is_registered:
		return
	_is_registered = _bank.start_continuous(_signature, wave_shape, effect,
		note, volume, entity.get_instance_id(),
		entity.global_position, positional)

## deregister this voice from the sound bank
func _deregister() -> void:
	if _bank == null or not _is_registered:
		return
	_bank.stop_continuous(_signature, entity.get_instance_id())
	_is_registered = false

## --- cleanup ---

## deregister on entity deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if stop_on_deactivate:
		_deregister()

## always deregister when removed from tree
func _exit_tree() -> void:
	_deregister()

## --- preview ---

## start editor preview playback
func _preview_play() -> void:
	_ensure_preview_player()
	_preview_player.play()
	call_deferred("_preview_fill")

## generate PCM audio frames for the preview tone
func _preview_fill() -> void:
	if not _preview_player or not _preview_player.playing:
		return
	var pb: AudioStreamGeneratorPlayback = _preview_player.get_stream_playback()
	if pb == null:
		return
	
	var freq: float = CDUtilities.freq_from_note(note)
	var phase: float = 0.0
	var total_frames: int = int(preview_duration * CDUtilities.MIX_RATE)
	
	for i in total_frames:
		var t: float = float(i) / CDUtilities.MIX_RATE
		var mod_freq: float = CDUtilities.apply_freq_effect(freq, t, effect)
		phase += mod_freq / CDUtilities.MIX_RATE
		var sample: float = CDUtilities.wave_sample(phase, wave_shape)
		sample = CDUtilities.apply_amp_effect(sample, t, 0.0, CDEnums.Effect.NONE)
		pb.push_frame(Vector2(sample * volume, sample * volume))

## stop editor preview playback
func _preview_stop() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()

## create or reuse the editor preview audio player
func _ensure_preview_player() -> void:
	if _preview_player and is_instance_valid(_preview_player):
		if _preview_player.playing:
			_preview_player.stop()
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CDUtilities.MIX_RATE
	gen.buffer_length = 1.0
	_preview_player = AudioStreamPlayer.new()
	_preview_player.stream = gen
	_preview_player.volume_db = 0.0
	_preview_player.bus = &"Master"
	add_child(_preview_player)
