@tool

## ongoing sound
class_name ContinuousVoice extends CDEntityComponent

@export var wave_shape: CDEnums.WaveShape = CDEnums.WaveShape.SQUARE
@export var effect: CDEnums.Effect = CDEnums.Effect.NONE
@export var note: CDEnums.Semitone = CDEnums.Semitone.C4
@export var volume: float = 0.2
@export var start_signal: StringName = &""
@export var stop_signal: StringName = &""
@export var filter_value: StringName = &""
@export var gameplay_only: bool = false
@export var start_on_spawn: bool = false
@export var stop_on_deactivate: bool = true
@export var positional: bool = true

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

func _build_signature() -> String:
	return "%d_%d_%d" % [wave_shape, effect, note]

func _on_start(arg1 = null) -> void:
	if filter_value != &"" and arg1 != filter_value:
		return
	_register()

func _on_stop(arg1 = null) -> void:
	if filter_value != &"" and arg1 != filter_value:
		return
	_deregister()

func _physics_process(_delta: float) -> void:
	if not _is_registered:
		return
	
	if gameplay_only:
		if game.current_state != CDEnums.GameState.PLAYING:
			_bank.pause_continuous(_signature, entity.get_instance_id())
			return
		else:
			_bank.resume_continuous(_signature, entity.get_instance_id())
	
	if positional:
		_bank.update_continuous_position(_signature, entity.get_instance_id(), entity.global_position)

func _register() -> void:
	if _bank == null or _is_registered:
		return
	_is_registered = _bank.start_continuous(_signature, wave_shape, effect,
		note, volume, entity.get_instance_id(),
		entity.global_position, positional)

func _deregister() -> void:
	if _bank == null or not _is_registered:
		return
	_bank.stop_continuous(_signature, entity.get_instance_id())
	_is_registered = false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	if stop_on_deactivate:
		_deregister()

func _exit_tree() -> void:
	_deregister()

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
