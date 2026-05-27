## playlist + dual-player crossfade + loop-point logic
class_name MusicSpeaker extends CDGameComponent

@export var playlist: Array[MusicTrack] = []
@export var loop: bool = false
@export var volume_db: float = -6.0
@export var idle_volume_db: float = -20.0
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.5
@export var crossfade_duration: float = 1.0

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _queue: Array[int] = []
var _current_index: int = -1
var _is_playing: bool = false
var _pitch_scale: float = 1.0

var pitch_scale: float:
	get:
		return _pitch_scale
	set(v):
		_pitch_scale = v
		if _player_a:
			_player_a.pitch_scale = v
		if _player_b:
			_player_b.pitch_scale = v

func _on_initialize() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = &"CD_Audio"
	add_child(_player_a)
	
	_player_b = AudioStreamPlayer.new()
	_player_b.bus = &"CD_Audio"
	add_child(_player_b)
	
	_active_player = _player_a
	
	game.bus_connect("game_play", _on_game_play)
	game.bus_connect("game_over", _on_game_over)

func _on_game_play() -> void:
	_start_playlist()

func _on_game_over(_result = null) -> void:
	_fade_out_and_stop()

func _start_playlist() -> void:
	if playlist.is_empty():
		return
	_queue = range(playlist.size())
	_queue.shuffle()
	_current_index = -1
	_is_playing = true
	_play_next()

func _play_next() -> void:
	if _queue.is_empty():
		if loop:
			_queue = range(playlist.size())
			_queue.shuffle()
		else:
			_is_playing = false
			return
	
	_current_index = _queue.pop_front()
	var track: MusicTrack = playlist[_current_index]
	
	# crossfade to the other player
	var fade_out_player: AudioStreamPlayer = _active_player
	_active_player = _player_a if _active_player == _player_b else _player_b
	
	_active_player.stream = track.stream
	_active_player.volume_db = -60.0
	_active_player.pitch_scale = _pitch_scale
	_active_player.play()
	
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", volume_db, crossfade_duration)
	tween.parallel().tween_property(fade_out_player, "volume_db", -60.0, crossfade_duration)
	tween.tween_callback(fade_out_player.stop)
	
	game.bus_emit("track_changed", [track])
	
	if track.loop_end > 0.0:
		_schedule_loop_crossfade(track)
	else:
		_schedule_next_on_finish()

func _schedule_loop_crossfade(track: MusicTrack) -> void:
	var wait_time: float = track.loop_end - track.loopfade_duration
	await get_tree().create_timer(wait_time).timeout
	if not _is_playing:
		return
	_active_player.play(track.loop_start)
	_schedule_loop_crossfade(track)

func _schedule_next_on_finish() -> void:
	await get_tree().create_timer(_get_stream_duration()).timeout
	if not _is_playing:
		return
	_play_next()

func _get_stream_duration() -> float:
	if _active_player and _active_player.stream:
		return _active_player.stream.get_length()
	return 0.0

func _fade_out_and_stop() -> void:
	_is_playing = false
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", -60.0, fade_out_duration)
	tween.tween_callback(_active_player.stop)
