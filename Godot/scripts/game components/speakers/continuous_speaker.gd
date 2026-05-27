@tool

## game-level continuous sound
class_name ContinuousSpeaker extends CDGameComponent

@export var wave_shape: CDEnums.WaveShape = CDEnums.WaveShape.SINE
@export var effect: CDEnums.Effect = CDEnums.Effect.NONE
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4
@export var volume: float = 0.1
@export var start_signal: StringName = &"game_play"
@export var stop_signal: StringName = &"game_over"

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

@export var preview_duration: float = 0.5

var _bank: CDSoundBank
var _signature: String
var _is_registered: bool = false
var _preview_player: AudioStreamPlayer

func _on_initialize() -> void:
	_bank = game.find_child("CDSoundBank") as CDSoundBank
	_signature = "%d_%d_%d" % [wave_shape, effect, note]
	
	if start_signal != &"":
		game.bus_connect(start_signal, _on_start)
	if stop_signal != &"":
		game.bus_connect(stop_signal, _on_stop)

func _on_start(_arg1 = null) -> void:
	if _bank == null or _is_registered:
		return
	var sound_position: Vector2 = game.game_bounds.get_center() if game.game_bounds.has_area() else Vector2.ZERO
	_is_registered = _bank.start_continuous(_signature, wave_shape, effect,
		note, volume, game.get_instance_id(), sound_position, false)

func _on_stop(_arg1 = null) -> void:
	_deregister()

func _deregister() -> void:
	if _bank == null or not _is_registered:
		return
	_bank.stop_continuous(_signature, game.get_instance_id())
	_is_registered = false

func _exit_tree() -> void:
	_deregister()
	if game:
		if start_signal != &"":
			game.bus_disconnect(start_signal, _on_start)
		if stop_signal != &"":
			game.bus_disconnect(stop_signal, _on_stop)

### preview

func _preview_play() -> void:
	_ensure_preview_player()
	_preview_player.play()
	call_deferred("_preview_fill")

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

func _preview_stop() -> void:
	if _preview_player and _preview_player.playing:
		_preview_player.stop()

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
