# CDCueCard
# Base class for all V2 UI display components
# Extends Control (not Node2D) — lives in UI layer, not physics world

class_name CDCueCard extends Control

# when true, auto-creates a child Label for text display
@export var is_interface: bool = false

# cached reference to ancestor game, resolved at _ready
@onready var game: CDGame = CDGame.find_ancestor(self)

# programmatically created label (only if is_interface is true)
var _label: Label

# fixed priority 70 (RULES) — cue cards process after all gameplay
func _ready():
	process_physics_priority = 70
	if is_interface:
		_create_label()

# create a bare Label child for text output
func _create_label():
	_label = Label.new()
	add_child(_label)

# call from subclasses when displayed state changes
func _update_label(text: String):
	if _label:
		_label.text = text
