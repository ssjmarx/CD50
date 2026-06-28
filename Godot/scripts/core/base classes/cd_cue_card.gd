## CDCueCard
## Base class for all V2 UI display components
## Extends Control (not Node2D) — lives in UI layer, not physics world Provides shared blackboard helpers for reading pending deltas and publishing tracked values

class_name CDCueCard extends CDGameControl

## --- exports ---

## when true, auto-creates a child Label for text display
@export var is_interface: bool = false

## --- cached refs ---

## game ref is inherited from CDGameControl (resolved in _on_initialize)

## programmatically created label (only if is_interface is true)
var _label: Label

## --- lifecycle ---

## base lifecycle (editor guard, priority 70, deferred _on_initialize), then label
func _ready():
	super._ready()
	if is_interface and not Engine.is_editor_hint():
		_create_label()

## --- label ---

## create a bare Label child for text output
func _create_label():
	_label = Label.new()
	add_child(_label)

## call from subclasses when displayed state changes
func _update_label(text: String):
	if _label:
		_label.text = text

## --- blackboard helpers ---

## read and clear a pending key from the game blackboard
## returns default if key not found or value is null
## rule 6: consumers have a sensible default
func _consume_pending(key: StringName, default: Variant = null) -> Variant:
	if not game:
		return default
	var value: Variant = game.blackboard.get(key, null)
	if value == null:
		return default
	game.blackboard.erase(key)
	return value

## write a tracked value to the game blackboard
## rule 5: components write transient state to parent blackboard
func _publish_tracked(key: StringName, value: Variant) -> void:
	if not game:
		return
	game.blackboard[key] = value