# CDGameComponent
# Base class for all V2 game-attached components
# Provides two-phase lifecycle and cached game ref (no entity ref)

class_name CDGameComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

# cached reference to ancestor game node
var game: CDGame

# --- Two-Phase Lifecycle ---

# Phase 1: resolve game ref, set priority, defer phase 2
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# walk tree to find ancestor game
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDGameComponent '%s': no CDGame ancestor found." % name)
		return

	# set processing order from component category
	process_physics_priority = CDEnums.category_to_priority(component_category)

	# defer initialization until all siblings have finished _ready
	call_deferred("_initialize")

# Phase 2: call virtual init for subclasses
func _initialize() -> void:
	_on_initialize()

# --- Virtual Methods ---

# Override to connect game bus signals and set up game-level logic
func _on_initialize() -> void:
	pass