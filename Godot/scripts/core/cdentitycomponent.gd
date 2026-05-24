### base class for all V2 entity-attached components.
class_name CDEntityComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached references for the component to use
var entity: CDEntity
var game: CDGame

## step one setup
func _ready() -> void:
	entity = CDEntity.find_ancestor(self)
	game = CDGame.find_ancestor(self)
	
	if entity == null:
		push_error("CDComponent2D '%s': no CDEntity ancestor found. Use CDStageComponent2D for CDGame children." % name)
		return
	if game == null:
		push_error("CDComponent2D '%s': no CDGame ancestor found." % name)
		return
	
	process_physics_priority = CDEnums.category_to_priority(component_category)
	
	call_deferred("_initialize")

## step two setup
func _initialize() -> void:
	_on_initialize()

## virtual method for subclass step two initialization
func _on_initialize() -> void:
	pass

## virtual method for subclass cleanup before deletion/pooling
func _on_entity_deactivating() -> void:
	pass

## virtual method for subclass reactivation from pool
func _on_entity_activated() -> void:
	pass
