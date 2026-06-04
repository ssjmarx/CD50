## MusicSpeaker
## Dual-player playlist crossfade system with shuffled tracks and loop-point support
## Emits track_changed on the game bus for credit overlay integration

class_name MusicSpeaker extends CDGameComponent

## --- exports ---

## ordered list of music tracks to play
@export var playlist: Array[CDMusicTrack] = []
## whether the playlist repeats after all tracks play
@export var loop: bool = false
## target volume during playback (dB)
@export var volume_db: float = -6.0
## idle/ambient volume (dB)
@export var idle_volume_db: float = -20.0
## fade-in duration when starting playback (seconds)
@export var fade_in_duration: float = 1.0
## fade-out duration when stopping (seconds)
@export var fade_out_duration: float = 0.5
## crossfade duration between tracks (seconds)
@export var crossfade_duration: float = 1.0

@export_group("Blackboard Keys")
## key for writing current track to game blackboard (CDMusicTrack)
@export var track_key: StringName = &"current_track"

## --- state ---

## two players for seamless crossfade transitions
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
## whichever player is currently the active (loudest) one
var _active_player: AudioStreamPlayer
## shuffled queue of track indices
var _queue: Array[int] = []
## index into playlist of the currently playing track
var _current_index: int = -1
## whether the speaker is actively playing
var _is_playing: bool = false
## pitch multiplier applied to both players
var _pitch_scale: float = 1.0

## --- properties ---

## pitch scale applied to both audio players in real time
var pitch_scale: float:
	get:
		return _pitch_scale
	set(v):
		_pitch_scale = v
		if _player_a:
			_player_a.pitch_scale = v
		if _player_b:
			_player_b.pitch_scale = v

## --- lifecycle ---

## create dual players and connect game state signals
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

## --- signal handlers ---

## start the playlist when the game begins
func _on_game_play() -> void:
	_start_playlist()

## fade out and stop when the game ends
func _on_game_over() -> void:
	_fade_out_and_stop()

## --- playlist management ---

## shuffle playlist indices and begin playback
func _start_playlist() -> void:
	if playlist.is_empty():
		return
	_queue = range(playlist.size())
	_queue.shuffle()
	_current_index = -1
	_is_playing = true
	_play_next()

## dequeue next track and crossfade to it
func _play_next() -> void:
	## reshuffle if queue is empty and looping
	if _queue.is_empty():
		if loop:
			_queue = range(playlist.size())
			_queue.shuffle()
		else:
			_is_playing = false
			return
	
	_current_index = _queue.pop_front()
	var track: CDMusicTrack = playlist[_current_index]
	
	var fade_out_player: AudioStreamPlayer = _active_player
	_active_player = _player_a if _active_player == _player_b else _player_b
	
	## configure and start new player at silent volume
	_active_player.stream = track.stream
	_active_player.volume_db = -60.0
	_active_player.pitch_scale = _pitch_scale
	_active_player.play()
	
	## parallel crossfade: new player in, old player out
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", volume_db, crossfade_duration)
	tween.parallel().tween_property(fade_out_player, "volume_db", -60.0, crossfade_duration)
	tween.tween_callback(fade_out_player.stop)
	
	game.blackboard[track_key] = track
	game.bus_emit("track_changed")
	
	## schedule what happens when this track ends
	if track.loop_end > 0.0:
		_schedule_loop_crossfade(track)
	else:
		_schedule_next_on_finish()

## --- track scheduling ---

## loop back to loop_start at loop_end with recursive rescheduling
func _schedule_loop_crossfade(track: CDMusicTrack) -> void:
	var wait_time: float = track.loop_end - track.loopfade_duration
	await get_tree().create_timer(wait_time).timeout
	if not _is_playing:
		return
	_active_player.play(track.loop_start)
	_schedule_loop_crossfade(track)

## wait for stream to finish then play next track
func _schedule_next_on_finish() -> void:
	await get_tree().create_timer(_get_stream_duration()).timeout
	if not _is_playing:
		return
	_play_next()

## return the duration of the currently active stream
func _get_stream_duration() -> float:
	if _active_player and _active_player.stream:
		return _active_player.stream.get_length()
	return 0.0

## --- fade out ---

## tween active player to silent then stop
func _fade_out_and_stop() -> void:
	_is_playing = false
	var tween := create_tween()
	tween.tween_property(_active_player, "volume_db", -60.0, fade_out_duration)
	tween.tween_callback(_active_player.stop)
