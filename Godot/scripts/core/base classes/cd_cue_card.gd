## CDCueCard
## Base class for all V2 UI display components
## Extends Control (not Node2D) — lives in UI layer, not physics world Provides shared blackboard helpers for reading pending deltas and publishing tracked values

class_name CDCueCard extends Control

## --- exports ---

## when true, auto-creates a child Label for text display
@export var is_interface: bool = false

## --- cached refs ---

## cached reference to ancestor game, resolved at _ready
@onready var game: CDGame = CDGame.find_ancestor(self)

## programmatically created label (only if is_interface is true)
var _label: Label

## --- lifecycle ---

## fixed priority 70 (RULES) — cue cards process after all gameplay
func _ready():
	process_physics_priority = 70
	if is_interface:
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