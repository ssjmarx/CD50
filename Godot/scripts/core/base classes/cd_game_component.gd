## CDGameComponent
## Base class for all V2 game-attached components
## Provides two-phase lifecycle, cached game ref, and bus tracking

class_name CDGameComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached reference to ancestor game node
var game: CDGame

## tracked bus connections for CDStage sleep/wake support
var _bus_connections: Array[Dictionary] = []  # [{"signal_name": StringName, "callable": Callable}]

## --- Two-Phase Lifecycle ---

## Phase 1: resolve game ref, defer phase 2 (priority set in _initialize after subclass _ready)
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	## walk tree to find ancestor game
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDGameComponent '%s': no CDGame ancestor found." % name)
		return

	call_deferred("_initialize")

## Phase 2: set priority from category (subclass _ready has already run), call virtual init
func _initialize() -> void:
	process_physics_priority = CDEnums.category_to_priority(component_category)
	_on_initialize()

## --- Virtual Methods ---

## Override to connect game bus signals and set up game-level logic
func _on_initialize() -> void:
	pass

## --- Bus Connection Tracking (for CDStage sleep/wake) ---

## Connect to game bus and track the connection for CDStage sleep/wake
func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not game.has_signal(signal_name):
		game.add_user_signal(signal_name)
	if not game.is_connected(signal_name, callable):
		game.connect(signal_name, callable)
	_bus_connections.append({"signal_name": signal_name, "callable": callable})

## Disconnect from game bus and untrack the connection.
func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
	if game.has_signal(signal_name) and game.is_connected(signal_name, callable):
		game.disconnect(signal_name, callable)
	for i in range(_bus_connections.size() - 1, -1, -1):
		if _bus_connections[i]["signal_name"] == signal_name and _bus_connections[i]["callable"] == callable:
			_bus_connections.remove_at(i)

## --- Sleep/Wake Virtual Methods (called by CDStage) ---

## Override to customize sleep behavior (clear timers, reset state, etc.)
func _on_sleep() -> void:
	set_physics_process(false)

## Override to customize wake behavior (restart timers, re-query state, etc.)
func _on_wake() -> void:
	set_physics_process(true)
