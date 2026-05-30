# ContinuousSpeaker
# Game-level sustained synthesized tone (drone, hum, alarm) via CDSoundBank
# Starts and stops on game bus signals with editor preview support

@tool
class_name ContinuousSpeaker extends CDGameComponent

# --- exports ---

# oscillator waveform shape
@export var wave_shape: CDEnums.WaveShape = CDEnums.WaveShape.SINE
# frequency/amplitude modulation effect
@export var effect: CDEnums.Effect = CDEnums.Effect.NONE
# base pitch note
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4
# output volume level
@export var volume: float = 0.1
# game bus signal that starts the tone
@export var start_signal: StringName = &"game_play"
# game bus signal that stops the tone
@export var stop_signal: StringName = &"game_over"

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
# duration of the preview tone in seconds
@export var preview_duration: float = 0.5

# --- state ---

# reference to the central sound bank
var _bank: CDSoundBank
# unique key for bank registration "{wave}_{effect}_{note}"
var _signature: String
# whether this speaker is currently registered with the bank
var _is_registered: bool = false
# editor-only preview audio player
var _preview_player: AudioStreamPlayer

# --- lifecycle ---

# find sound bank, build signature, connect start/stop signals
func _on_initialize() -> void:
	_bank = game.find_child("CDSoundBank") as CDSoundBank
	_signature = "%d_%d_%d" % [wave_shape, effect, note]
	
	if start_signal != &"":
		game.bus_connect(start_signal, _on_start)
	if stop_signal != &"":
		game.bus_connect(stop_signal, _on_stop)

# deregister and disconnect on removal
func _exit_tree() -> void:
	_deregister()
	if game:
		if start_signal != &"":
			game.bus_disconnect(start_signal, _on_start)
		if stop_signal != &"":
			game.bus_disconnect(stop_signal, _on_stop)

# --- signal handlers ---

# register continuous tone with the sound bank
func _on_start(_arg1 = null) -> void:
	if _bank == null or _is_registered:
		return
	var sound_position: Vector2 = game.game_bounds.get_center() if game.game_bounds.has_area() else Vector2.ZERO
	_is_registered = _bank.start_continuous(_signature, wave_shape, effect,
		note, volume, game.get_instance_id(), sound_position, false)

# stop the continuous tone
func _on_stop(_arg1 = null) -> void:
	_deregister()

# --- bank management ---

# deregister this speaker from the sound bank
func _deregister() -> void:
	if _bank == null or not _is_registered:
		return
	_bank.stop_continuous(_signature, game.get_instance_id())
	_is_registered = false

# --- editor preview ---

# start playing the tone in the editor
func _preview_play() -> void:
	_ensure_preview_player()
	_preview_player.play()
	call_deferred("_preview_fill")

# fill the preview audio buffer with synthesized samples
func _preview_fill() -> void:
	if not _preview_player or not _preview_player.playing:
		return
	var pb: AudioStreamGeneratorPlayback = _preview_player.get_stream_playback()
	if pb == null:
		return
	
	var freq: float = CDUtilities.freq_from_note(note)
	var phase: float = 0.0
	var total_frames: int = int(preview_duration * CDUtilities.MIX_RATE)
	
	# generate preview samples with wave shape and effects
	for i in total_frames:
		var t: float = float(i) / CDUtilities.MIX_RATE
		var mod_freq: float = CDUtilities.apply_freq_effect(freq, t, effect)
		phase += mod_freq / CDUtilities.MIX_RATE
		var sample: float = CDUtilities.wave_sample(phase, wave_shape)
		sample = CDUtilities.apply_amp_effect(sample, t, 0.0, CDEnums.Effect.NONE)
		pb.push_frame(Vector2(sample * volume, sample * volume))

# stop the editor preview
func _preview_stop() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()

# create or reset the preview AudioStreamPlayer
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
