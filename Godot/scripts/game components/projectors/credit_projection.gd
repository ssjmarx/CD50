## floating credit overlay showing track title and artist
class_name CreditProjection extends Control

@export var display_time: float = 5.0
@export var font: Font

@export_group("Listen Signals")
@export var track_changed_signals: Array[StringName] = [&"track_changed"]

var _container: Control = null
var _tween: Tween = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_physics_priority = 70
	call_deferred("_on_initialize")

func _on_initialize() -> void:
	var game := CDGame.find_ancestor(self)
	if not game:
		return
	for sig in track_changed_signals:
		game.bus_connect(sig, _on_track_changed)

func _on_track_changed(track: CDMusicTrack) -> void:
	_clear_credit()
	if not track or (track.title == "" and track.artist == ""):
		return
	_show_credit(track)

func _show_credit(track: CDMusicTrack) -> void:
	_container = Control.new()
	_container.name = "CreditContainer"
	_container.modulate.a = 0.0
	add_child(_container)

	var line_height: float = 20.0
	var left_margin: float = 16.0
	var top_margin: float = 16.0

	if track.title != "":
		var title_label := Label.new()
		title_label.name = "TitleLabel"
		title_label.label_settings = LabelSettings.new()
		title_label.label_settings.font = font
		title_label.label_settings.font_size = 24
		title_label.label_settings.font_color = Color(1, 1, 1, 0.9)
		title_label.label_settings.outline_color = Color.BLACK
		title_label.label_settings.outline_size = 2
		title_label.text = track.title
		title_label.offset_left = left_margin
		title_label.offset_top = top_margin
		title_label.offset_right = left_margin + 600.0
		title_label.offset_bottom = top_margin + line_height
		_container.add_child(title_label)
		top_margin += line_height

	if track.artist != "":
		var artist_label := Label.new()
		artist_label.name = "ArtistLabel"
		artist_label.label_settings = LabelSettings.new()
		artist_label.label_settings.font = font
		artist_label.label_settings.font_size = 24
		artist_label.label_settings.font_color = Color(1, 1, 1, 0.9)
		artist_label.label_settings.outline_color = Color.BLACK
		artist_label.label_settings.outline_size = 2
		artist_label.text = track.artist
		artist_label.offset_left = left_margin
		artist_label.offset_top = top_margin
		artist_label.offset_right = left_margin + 600.0
		artist_label.offset_bottom = top_margin + line_height
		_container.add_child(artist_label)

	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
	_tween.tween_interval(display_time)
	_tween.tween_property(_container, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_clear_credit)

func _clear_credit() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _container and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_tween = null
