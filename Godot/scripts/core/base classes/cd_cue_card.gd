## cd_cue_card.gd
## Produces: UI label text and tracked blackboard values for display components.
## Consumes: game.blackboard pending keys; subclass display state.
@tool

class_name CDCueCard extends CDGameControl

## when true, auto-create a child Label for text display
@export var is_interface: bool = false:
	set(value):
		is_interface = value
		_update_interface()

## font size for the auto-label
@export var font_size: int = 16:
	set(value):
		font_size = value
		_update_interface()

## text prepended to the label value
@export var label_prefix: String = "":
	set(value):
		label_prefix = value
		_update_interface()

## text appended to the label value
@export var label_suffix: String = "":
	set(value):
		label_suffix = value
		_update_interface()

## programmatically created label (only active during runtime)
var _label: Label

## Run base lifecycle, then sync the auto-label if enabled.
func _ready() -> void:
	super._ready()
	_update_interface()

## Draws an editor-only preview without adding nodes to the scene tree.
func _draw() -> void:
	if Engine.is_editor_hint() and is_interface:
		var font := get_theme_default_font()
		if font:
			var text := label_prefix + "Preview" + label_suffix
			var pos := Vector2(0, font.get_ascent(font_size))
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## Manage the runtime label or request an editor redraw.
func _update_interface() -> void:
	if not is_inside_tree():
		return
		
	if Engine.is_editor_hint():
		# Force the editor viewport to refresh the _draw() preview
		queue_redraw()
	else:
		# Runtime behavior: create the actual Label node
		if is_interface:
			if not _label:
				_label = Label.new()
				add_child(_label)
			_label.add_theme_font_size_override("font_size", font_size)
		elif _label:
			_label.queue_free()
			_label = null

## Set the auto-label's text; call from subclasses when displayed state changes.
func _update_label(text: String) -> void:
	if _label:
		_label.text = label_prefix + text + label_suffix

## Read and clear a pending key from the game blackboard, returning default if missing.
func _consume_pending(key: StringName, default: Variant = null) -> Variant:
	if not game:
		return default
	var value: Variant = game.blackboard.get(key, null)
	if value == null:
		return default
	game.blackboard.erase(key)
	return value

## Write a tracked value to the game blackboard.
func _publish_tracked(key: StringName, value: Variant) -> void:
	if not game:
		return
	game.blackboard[key] = value
