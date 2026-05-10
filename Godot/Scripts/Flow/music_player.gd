# Music player. Shuffles and plays through an array of MusicTrack resources with
# fade in/out and a floating credit overlay. Only plays in STANDALONE mode.
# If loop is true, repeats the first track forever instead of advancing.
# Shows credits for ~5 seconds per track as floating text, then auto-hides.

extends UniversalComponent2D

@export var playlist: Array[MusicTrack] = []
@export var loop: bool = false
@export var volume_db: float = -10.0
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.5
@export var credit_display_time: float = 5.0

# Speed ramping — listens for a signal and increases pitch_scale per fire
@export var speed_ramp_source: Node
@export var speed_ramp_signal: String = ""
@export var speed_per_level: float = 0.1

var _player: AudioStreamPlayer
var _credit_layer: CanvasLayer
var _credit_tween: Tween = null
var _queue: Array[MusicTrack] = []
var _current_track: MusicTrack = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	_player.bus = "Master"
	add_child(_player)
	_player.finished.connect(_on_track_finished)

	game.state_changed.connect(_on_state_changed)

	if speed_ramp_source and speed_ramp_signal != "":
		speed_ramp_source.connect(speed_ramp_signal, _on_speed_ramp)

func _on_state_changed(new_state: int) -> void:
	match new_state:
		CommonEnums.State.PLAYING:
			if game.mode == UniversalGameScript.Mode.STANDALONE:
				_play_next()
		CommonEnums.State.GAME_OVER:
			_stop()

func _on_track_finished() -> void:
	if loop:
		_player.play()
	else:
		_play_next()

func _play_next() -> void:
	if _queue.is_empty():
		_queue = playlist.duplicate()
		_queue.shuffle()
	_current_track = _queue.pop_front()
	_player.stream = _current_track.stream
	_player.play()
	_fade_in()
	_show_credit(_current_track)

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(_player, "volume_db", volume_db, fade_in_duration)

func _stop() -> void:
	if _credit_tween and _credit_tween.is_valid():
		_credit_tween.kill()
	_hide_credit()
	var tween = create_tween()
	tween.tween_property(_player, "volume_db", -80.0, fade_out_duration)
	tween.tween_callback(_player.stop)

# --- Speed Ramping ---

func _on_speed_ramp(_arg = null) -> void:
	_player.pitch_scale = minf(_player.pitch_scale + speed_per_level, 3.0)

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

	var font = load("res://Assets/Fonts/Kenney Pixel.ttf")

	# Song credit — large floating text, centered
	var label = Label.new()
	label.name = "CreditLabel"
	label.label_settings = LabelSettings.new()
	label.label_settings.font = font
	label.label_settings.font_size = 24
	label.label_settings.font_color = Color(1, 1, 1, 0.9)
	label.label_settings.outline_color = Color.BLACK
	label.label_settings.outline_size = 2
	label.text = "♪ %s — %s" % [track.song_title, track.song_credit]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.offset_top = 310.0
	label.offset_bottom = 340.0
	container.add_child(label)

	# Render credit — smaller, below
	if track.render_credit != "":
		var render_label = Label.new()
		render_label.name = "RenderLabel"
		render_label.label_settings = LabelSettings.new()
		render_label.label_settings.font = font
		render_label.label_settings.font_size = 16
		render_label.label_settings.font_color = Color(0.8, 0.8, 0.8, 0.7)
		render_label.label_settings.outline_color = Color.BLACK
		render_label.label_settings.outline_size = 2
		render_label.text = track.render_credit
		render_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		render_label.anchor_right = 1.0
		render_label.offset_top = 336.0
		render_label.offset_bottom = 356.0
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
