## CDGameControl
## Base class for V2 game-attached Control-rooted nodes
## Mirrors the CDGameComponent contract: cached game ref, two-phase lifecycle, bus tracking
## Use for UI overlays/projections that must extend Control instead of Node2D

class_name CDGameControl extends Control

## cached reference to ancestor game node
var game: CDGame

## tracked bus connections for auto-disconnect on _exit_tree
var _bus_connections: Array[Dictionary] = []  # [{"signal_name": StringName, "callable": Callable}]

## --- Two-Phase Lifecycle ---

## Phase 1: resolve game ref, defer phase 2
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_physics_priority = 70
	call_deferred("_on_initialize")

## --- Virtual Methods ---

## Override to connect game bus signals and set up game-level logic
func _on_initialize() -> void:
	game = CDGame.find_ancestor(self)
	if not game:
		push_warning("CDGameControl '%s' has no CDGame ancestor." % name)

## --- Bus Connection Tracking ---

## Connect to game bus and track the connection for auto-disconnect
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

## Connect to every signal in the array; tracked for auto-disconnect on _exit_tree.
func connect_all(signals: Array[StringName], callable: Callable) -> void:
	for sig in signals:
		bus_connect(sig, callable)

## Disconnect from every signal in the array.
func disconnect_all(signals: Array[StringName], callable: Callable) -> void:
	for sig in signals:
		bus_disconnect(sig, callable)

## Auto-disconnect all tracked game bus connections when leaving the tree.
func _exit_tree() -> void:
	if game:
		for entry in _bus_connections.duplicate():
			game.bus_disconnect(entry["signal_name"], entry["callable"])