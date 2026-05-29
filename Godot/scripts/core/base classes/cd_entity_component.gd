### base class for all V2 entity-attached components.
class_name CDEntityComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached references for the component to use
var entity: CDEntity
var game: CDGame

## step one setup
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	process_physics_priority = CDEnums.category_to_priority(component_category)
	
	entity = CDEntity.find_ancestor(self)
	if entity == null:
		push_error("CDComponent2D '%s': no CDEntity ancestor found." % name)
		return
	
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDComponent2D '%s': no CDGame ancestor found." % name)
		return
	
	call_deferred("_initialize")

## step two setup
func _initialize() -> void:
	entity.connect("entity_deactivating", _on_entity_deactivating)
	entity.connect("entity_activated", _on_entity_activated)
	_on_initialize()


## virtual method for subclass step two initialization
func _on_initialize() -> void:
	pass

## virtual method for subclass cleanup before deletion/pooling
func _on_entity_deactivating() -> void:
	set_physics_process(false)

## virtual method for subclass reactivation from pool
func _on_entity_activated() -> void:
	set_physics_process(true)
