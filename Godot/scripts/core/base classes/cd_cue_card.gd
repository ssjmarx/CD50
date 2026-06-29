## cd_cue_card.gd
## Produces: UI label text and tracked blackboard values for display components.
## Consumes: game.blackboard pending keys; subclass display state.
class_name CDCueCard extends CDGameControl

## when true, auto-create a child Label for text display
@export var is_interface: bool = false

## programmatically created label (only if is_interface is true)
var _label: Label

## Run base lifecycle, then create the auto-label if enabled.
func _ready():
	super._ready()
	if is_interface and not Engine.is_editor_hint():
		_create_label()

## Create a bare Label child for text output.
func _create_label():
	_label = Label.new()
	add_child(_label)

## Set the auto-label's text; call from subclasses when displayed state changes.
func _update_label(text: String):
	if _label:
		_label.text = text

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