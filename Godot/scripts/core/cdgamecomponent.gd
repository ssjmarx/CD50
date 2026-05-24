## base class for all v2 game attached components
class_name CDGameComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached reference to game
var game: CDGame

## step one setup
func _ready() -> void:
	game = CDGame.find_ancestor(self)
	
	if game == null:
		push_error("CDGameComponent '%s': no CDGame ancestor found." % name)
		return
	
	process_physics_priority = CDEnums.category_to_priority(component_category)
	
	call_deferred("_initialize")

## step two setup
func _initialize() -> void:
	_on_initialize()

## step two setup virtual method
func _on_initialize() -> void:
	pass
