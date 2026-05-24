# Music player. Shuffles and plays through an array of MusicTrack resources with
# fade in/out and a floating credit overlay.
# Uses dual AudioStreamPlayers (A/B) for seamless loop crossfading.
# First play starts from 0:00 (intro included). On loop, crossfades back to loop_start,
# skipping the outro→intro dead zone. Tracks change on restart only.

extends UniversalComponent2D

@export var playlist: Array[MusicTrack] = []
@export var loop: bool = false
@export var volume_db: float = -6.0
@export var idle_volume_db: float = -20.0
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.5
@export var crossfade_duration: float = 1.0
@export var credit_display_time: float = 5.0

# Speed ramping — listens for a signal and increases pitch_scale per fire
@export var speed_ramp_source: Node
@export var speed_ramp_signal: String = ""
@export var speed_per_level: float = 0.1

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _credit_layer: CanvasLayer
var _credit_tween: Tween = null
var _queue: Array[MusicTrack] = []
var _current_track: MusicTrack = null
var _playing: bool = false
var _looping: bool = false  # true after first pass completes; enables loop-spot logic
var _loop_crossfading: bool = false  # true while a loop crossfade is in progress

func _ready() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.name = "PlayerA"
	_player_a.volume_db = -80.0
	_player_a.bus = "Master"
	add_child(_player_a)
	
	_player_b = AudioStreamPlayer.new()
	_player_b.name = "PlayerB"
	_player_b.volume_db = -80.0
	_player_b.bus = "Master"
	add_child(_player_b)
	
	_active_player = _player_a
	
	_player_a.finished.connect(_on_track_finished.bind(_player_a))
	_player_b.finished.connect(_on_track_finished.bind(_player_b))
	
	if game:
		game.state_changed.connect(_on_state_changed)
	
	if speed_ramp_source and speed_ramp_signal != "":
		speed_ramp_source.connect(speed_ramp_signal, _on_speed_ramp)

func _process(_delta: float) -> void:
	if not _playing or not _current_track or _loop_crossfading:
		return
	
	# Only monitor loop position after the first pass
	if not _looping:
		return
	
	var pos: float = _active_player.get_playback_position()
	var end: float = _get_loop_end()
	
	if end > 0.0 and pos >= end - crossfade_duration:
		_do_loop_crossfade()

# --- Public API ---

func start() -> void:
	if not _playing:
		_playing = true
		_play_next()

func fade_to(target_db: float, duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(_active_player, "volume_db", target_db, duration)

func advance_track() -> void:
	_play_next()

# --- Internal ---

func _get_loop_end() -> float:
	if not _current_track:
		return 0.0
	if _current_track.loop_end >= 0.0:
		return _current_track.loop_end
	# Default: use the stream's natural length
	if _active_player.stream:
		return _active_player.stream.get_length()
	return 0.0

func _do_loop_crossfade() -> void:
	if _loop_crossfading:
		return
	_loop_crossfading = true
	
	# Pick the inactive player
	var incoming: AudioStreamPlayer
	if _active_player == _player_a:
		incoming = _player_b
	else:
		incoming = _player_a
	
	# Setup incoming: same track, seek to loop_start
	incoming.stream = _current_track.stream
	incoming.volume_db = -80.0
	incoming.play()
	incoming.seek(_current_track.loop_start)
	
	# Determine current volume (preserve idle vs gameplay level)
	var current_target: float = _active_player.volume_db
	
	# Crossfade: outgoing fades down, incoming fades up
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_active_player, "volume_db", -80.0, crossfade_duration)
	tween.tween_property(incoming, "volume_db", current_target, crossfade_duration)
	tween.set_parallel(false)
	tween.tween_callback(func():
		_active_player.stop()
		_active_player = incoming
		_loop_crossfading = false
	)

func _on_state_changed(new_state: int) -> void:
	match new_state:
		CommonEnums.State.PLAYING:
			if game.mode == UniversalGameScript.Mode.STANDALONE:
				_play_next()
		CommonEnums.State.GAME_OVER:
			_stop()

func _on_track_finished(player: AudioStreamPlayer) -> void:
	# If a player finishes and we're not already crossfading, first pass is done
	if player == _active_player and not _loop_crossfading:
		if loop or _current_track.loop_end >= 0.0 or (_current_track.loop_start > 0.0):
			# Enable loop-spot logic for subsequent plays
			_looping = true
			# Restart from loop_start immediately (first pass ended naturally)
			_active_player.play()
			if _looping:
				_active_player.seek(_current_track.loop_start)
		else:
			_play_next()

func _play_next() -> void:
	if _queue.is_empty():
		_queue = playlist.duplicate()
		_queue.shuffle()
	_current_track = _queue.pop_front()
	_looping = false
	_loop_crossfading = false
	
	if not _current_track or not _current_track.stream:
		return
	
	# Stop whatever is currently playing and start the new track from 0:00
	_player_a.stop()
	_player_b.stop()
	_active_player = _player_a
	_active_player.stream = _current_track.stream
	_active_player.volume_db = -80.0
	_active_player.play()
	_fade_in()
	_show_credit(_current_track)

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(_active_player, "volume_db", idle_volume_db, fade_in_duration)

func _stop() -> void:
	if _credit_tween and _credit_tween.is_valid():
		_credit_tween.kill()
	_hide_credit()
	var tween = create_tween()
	tween.tween_property(_active_player, "volume_db", -80.0, fade_out_duration)
	tween.tween_callback(_active_player.stop)

# --- Speed Ramping ---

func _on_speed_ramp(_arg = null) -> void:
	_active_player.pitch_scale = minf(_active_player.pitch_scale + speed_per_level, 3.0)

# --- Floating Credit Overlay ---

func _show_credit(track: MusicTrack) -> void:
	_hide_credit()

	_credit_layer = CanvasLayer.new()
	_credit_layer.layer = 100
	add_child(_credit_layer)

	var container = Control.new()
	container.name = "CreditContainer"
	container.modulate.a = 0.0
	_credit_layer.add_child(container)

	var font = load("res://v1/Assets/Fonts/Kenney Pixel.ttf")
	var line_height: float = 20.0
	var left_margin: float = 16.0
	var top_margin: float = 16.0

	# Song title — top-left
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.label_settings = LabelSettings.new()
	title_label.label_settings.font = font
	title_label.label_settings.font_size = 24
	title_label.label_settings.font_color = Color(1, 1, 1, 0.9)
	title_label.label_settings.outline_color = Color.BLACK
	title_label.label_settings.outline_size = 2
	title_label.text = track.song_title
	title_label.offset_left = left_margin
	title_label.offset_top = top_margin
	title_label.offset_right = left_margin + 600.0
	title_label.offset_bottom = top_margin + line_height
	container.add_child(title_label)

	# Song credit — below title
	var credit_label = Label.new()
	credit_label.name = "CreditLabel"
	credit_label.label_settings = LabelSettings.new()
	credit_label.label_settings.font = font
	credit_label.label_settings.font_size = 24
	credit_label.label_settings.font_color = Color(1, 1, 1, 0.9)
	credit_label.label_settings.outline_color = Color.BLACK
	credit_label.label_settings.outline_size = 2
	credit_label.text = track.song_credit
	credit_label.offset_left = left_margin
	credit_label.offset_top = top_margin + line_height
	credit_label.offset_right = left_margin + 600.0
	credit_label.offset_bottom = top_margin + line_height * 2.0
	container.add_child(credit_label)

	# Render credit — below song credit, same style
	if track.render_credit != "":
		var render_label = Label.new()
		render_label.name = "RenderLabel"
		render_label.label_settings = LabelSettings.new()
		render_label.label_settings.font = font
		render_label.label_settings.font_size = 24
		render_label.label_settings.font_color = Color(1, 1, 1, 0.9)
		render_label.label_settings.outline_color = Color.BLACK
		render_label.label_settings.outline_size = 2
		render_label.text = track.render_credit
		render_label.offset_left = left_margin
		render_label.offset_top = top_margin + line_height * 2.0
		render_label.offset_right = left_margin + 600.0
		render_label.offset_bottom = top_margin + line_height * 3.0
		container.add_child(render_label)

	# Animate: fade in, hold, fade out
	_credit_tween = create_tween()
	_credit_tween.tween_property(container, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
	_credit_tween.tween_interval(credit_display_time)
	_credit_tween.tween_property(container, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	_credit_tween.tween_callback(_hide_credit)

func _hide_credit() -> void:
	if _credit_layer and is_instance_valid(_credit_layer):
		_credit_layer.queue_free()
		_credit_layer = null
