## CreditProjection
## Floating credit overlay showing track title and artist when music changes
## Fades in, holds, then fades out using a Tween sequence Reads track info from game blackboard on zero-arg track_changed signal

class_name CreditProjection extends Control

## --- exports ---

## how long the credit stays visible before fading out
@export var display_time: float = 5.0
## font used for title and artist labels
@export var font: Font

@export_group("Blackboard Keys")
## key to read the current track from game blackboard (CDMusicTrack)
@export var track_key: StringName = &"current_track"

## game bus signals that trigger the credit display (zero-arg)
@export_group("Listen Signals")
@export var track_changed_signals: Array[StringName] = [&"track_changed"]

## --- state ---

## reference to the ancestor game controller
var _game: CDGame
## dynamically created container holding the labels
var _container: Control = null
## active tween driving the fade in/hold/fade out sequence
var _tween: Tween = null

## --- lifecycle ---

## skip processing in editor, initialize after tree is ready
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_physics_priority = 70
	call_deferred("_on_initialize")

## connect track change signals to the game bus
func _on_initialize() -> void:
	_game = CDGame.find_ancestor(self)
	if not _game:
		return
	for sig in track_changed_signals:
		_game.bus_connect(sig, _on_track_changed)

## --- signal handlers ---

## read track from blackboard and show credit if track has info (zero-arg)
func _on_track_changed() -> void:
	_clear_credit()
	var track: CDMusicTrack = _game.blackboard.get(track_key, null)
	if not track or (track.title == "" and track.artist == ""):
		return
	_show_credit(track)

## --- credit display ---

## build label nodes and animate the credit overlay
func _show_credit(track: CDMusicTrack) -> void:
	## create container to hold labels
	_container = Control.new()
	_container.name = "CreditContainer"
	_container.modulate.a = 0.0
	add_child(_container)

	var line_height: float = 20.0
	var left_margin: float = 16.0
	var top_margin: float = 16.0

	## add title label if track has a title
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

	## add artist label if track has an artist
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

	## animate: fade in → hold → fade out → cleanup
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
	_tween.tween_interval(display_time)
	_tween.tween_property(_container, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_clear_credit)

## --- cleanup ---

## kill active tween and free container nodes
func _clear_credit() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _container and is_instance_valid(_container):
		_container.queue_free()
	_container = null
	_tween = null