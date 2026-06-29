## cd_sequence_curve.gd
## Produces: a composite curve that cycles through child curves per call.
## Consumes: CDCurve child resources; nothing on write.
@tool
class_name CDSequenceCurve extends CDCurve

enum SequenceMode {
	SEQUENTIAL,       ## A → B → C → A → B → C ...
	RANDOM,           ## Random selection each call
	PING_PONG,        ## A → B → C → B → A → B → C ...
	RANDOM_NO_REPEAT, ## Random but never the same twice in a row
}

## ordered list of child curves to cycle through
@export var curves: Array[CDCurve] = []:
	set(v):
		_disconnect_children()
		curves = v
		_connect_children()
		emit_changed()

## cycling mode that determines how the index advances
@export var mode: SequenceMode = SequenceMode.SEQUENTIAL:
	set(v):
		mode = v
		emit_changed()

## editor-only: which child curve to show in the preview drawing
@export_group("Preview")
@export var preview_index: int = 0:
	set(v):
		preview_index = clampi(v, 0, maxi(0, curves.size() - 1))
		emit_changed()

var _current_index: int = 0
var _ping_pong_direction: int = 1

## Enter tree.
func _enter_tree() -> void:
	_connect_children()

## Exit tree.
func _exit_tree() -> void:
	_disconnect_children()

## --- Child Curve Change Forwarding ---

## Connect children.
func _connect_children() -> void:
	for child in curves:
		if child and not child.changed.is_connected(_on_child_changed):
			child.changed.connect(_on_child_changed)

## Disconnect children.
func _disconnect_children() -> void:
	for child in curves:
		if child and child.changed.is_connected(_on_child_changed):
			child.changed.disconnect(_on_child_changed)

## On child changed.
func _on_child_changed() -> void:
	emit_changed()

## Generate curve by delegating to the current child curve.
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	if curves.is_empty():
		return null

	var idx := _current_index
	if Engine.is_editor_hint():
		idx = clampi(preview_index, 0, curves.size() - 1)

	var result := curves[idx].generate_curve(start, end)

	if not Engine.is_editor_hint():
		_advance()

	if not result:
		return null

	return _finalize(result)

## Advance the child index according to the current mode.
func _advance() -> void:
	if curves.size() <= 1:
		return

	match mode:
		SequenceMode.SEQUENTIAL:
			_current_index = (_current_index + 1) % curves.size()

		SequenceMode.RANDOM:
			_current_index = randi() % curves.size()

		SequenceMode.PING_PONG:
			_current_index += _ping_pong_direction
			if _current_index >= curves.size() - 1:
				_ping_pong_direction = -1
			elif _current_index <= 0:
				_ping_pong_direction = 1
			_current_index = clampi(_current_index, 0, curves.size() - 1)

		SequenceMode.RANDOM_NO_REPEAT:
			if curves.size() <= 1:
				return
			var prev := _current_index
			_current_index = randi() % curves.size()
			while _current_index == prev:
				_current_index = randi() % curves.size()

## Reset index and ping-pong direction for game restart.
func reset() -> void:
	_current_index = 0
	_ping_pong_direction = 1