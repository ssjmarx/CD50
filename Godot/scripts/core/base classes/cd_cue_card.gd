## base class for all cue cards which are control instead of node2d
class_name CDCueCard extends Control

@export var is_interface: bool = false

@onready var game: CDGame = CDGame.find_ancestor(self)

var _label: Label

func _ready():
	process_physics_priority = 70
	if is_interface:
		_create_label()

func _create_label():
	_label = Label.new()
	add_child(_label)

## called by subclasses when state changes
func _update_label(text: String):
	if _label:
		_label.text = text
