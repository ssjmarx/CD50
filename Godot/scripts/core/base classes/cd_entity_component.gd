# CDEntityComponent
# Base class for all V2 entity-attached components
# Provides two-phase lifecycle, cached entity/game refs, and pool hooks

class_name CDEntityComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

# cached references — resolved in _ready, safe to use from _on_initialize onward
var entity: CDEntity
var game: CDGame

# --- Two-Phase Lifecycle ---

# Phase 1: resolve refs, set priority, defer phase 2
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# set processing order from component category (Brain=10, Leg=20, etc.)
	process_physics_priority = CDEnums.category_to_priority(component_category)

	# walk tree to find parent entity
	entity = CDEntity.find_ancestor(self)
	if entity == null:
		push_error("CDComponent2D '%s': no CDEntity ancestor found." % name)
		return

	# walk tree to find ancestor game
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDComponent2D '%s': no CDGame ancestor found." % name)
		return

	# defer initialization until all siblings have finished _ready
	call_deferred("_initialize")

# Phase 2: connect lifecycle signals, then call virtual init
func _initialize() -> void:
	entity.connect("entity_deactivating", _on_entity_deactivating)
	entity.connect("entity_activated", _on_entity_activated)
	_on_initialize()

# --- Virtual Methods ---

# Override to connect entity/game bus signals and read sibling state
func _on_initialize() -> void:
	pass

# Override to reset internal state before pool return or deletion
func _on_entity_deactivating() -> void:
	set_physics_process(false)

# Override to re-enable processing when recycled from pool
func _on_entity_activated() -> void:
	set_physics_process(true)