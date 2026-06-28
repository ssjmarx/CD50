## CDEntityComponent
## Base class for all V2 entity-attached components
## Provides two-phase lifecycle, cached entity/game refs, pool hooks, and bus tracking

class_name CDEntityComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached references — resolved in _ready, safe to use from _on_initialize onward
var entity: CDEntity
var game: CDGame

## tracked bus connections for CDBody sleep/wake support
var _bus_connections: Array[Dictionary] = []  # [{"signal_name": StringName, "callable": Callable}]

## --- Two-Phase Lifecycle ---

## Phase 1: resolve refs, set priority, defer phase 2
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_physics_priority = CDEnums.category_to_priority(component_category)

	## walk tree to find parent entity
	entity = CDEntity.find_ancestor(self)
	if entity == null:
		push_error("CDComponent2D '%s': no CDEntity ancestor found." % name)
		return

	## walk tree to find ancestor game
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDComponent2D '%s': no CDGame ancestor found." % name)
		return

	call_deferred("_initialize")

## Phase 2: connect lifecycle signals, then call virtual init
func _initialize() -> void:
	entity.connect("entity_deactivating", _on_entity_deactivating)
	entity.connect("entity_activated", _on_entity_activated)
	_on_initialize()

## --- Virtual Methods ---

## Override to connect entity/game bus signals and read sibling state
func _on_initialize() -> void:
	pass

## Override to reset internal state before pool return or deletion
func _on_entity_deactivating() -> void:
	set_physics_process(false)

## Override to re-enable processing when recycled from pool
func _on_entity_activated() -> void:
	set_physics_process(true)

## --- Bus Connection Tracking (for CDBody sleep/wake) ---

## Connect to entity bus and track the connection for CDBody sleep/wake
func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not entity.has_signal(signal_name):
		entity.add_user_signal(signal_name)
	if not entity.is_connected(signal_name, callable):
		entity.connect(signal_name, callable)
	_bus_connections.append({"signal_name": signal_name, "callable": callable})

## Disconnect from entity bus and untrack the connection.
func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
	if entity.has_signal(signal_name) and entity.is_connected(signal_name, callable):
		entity.disconnect(signal_name, callable)
	for i in range(_bus_connections.size() - 1, -1, -1):
		if _bus_connections[i]["signal_name"] == signal_name and _bus_connections[i]["callable"] == callable:
			_bus_connections.remove_at(i)

## Connect to every signal in the array; tracked for auto-disconnect on _exit_tree.
func connect_all(signals: Array[StringName], callable: Callable) -> void:
	for sig in signals:
		bus_connect(sig, callable)

## Disconnect from every signal in the array.
func disconnect_all(signals: Array[StringName], callable: Callable) -> void:
	for sig in signals:
		bus_disconnect(sig, callable)

## Auto-disconnect all tracked entity bus connections when leaving the tree.
func _exit_tree() -> void:
	if entity:
		for entry in _bus_connections.duplicate():
			entity.bus_disconnect(entry["signal_name"], entry["callable"])

## --- Sleep/Wake Virtual Methods (called by CDBody) ---

## Override to customize sleep behavior (clear timers, reset state, etc.)
func _on_sleep() -> void:
	set_physics_process(false)

## Override to customize wake behavior (restart timers, re-query state, etc.)
func _on_wake() -> void:
	set_physics_process(true)
