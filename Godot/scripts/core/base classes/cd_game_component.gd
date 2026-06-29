## cd_game_component.gd
## Produces: a resolved game ref and tracked bus connections for a game component.
## Consumes: the game tree (CDGame ancestor); bus signals.
class_name CDGameComponent extends Node2D

@export var component_category: CDEnums.ComponentCategory

## cached reference to ancestor game node
var game: CDGame

## tracked bus connections for CDStage sleep/wake support
var _bus_connections: Array[Dictionary] = []

## Resolve game ref and defer phase 2 initialization.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDGameComponent '%s': no CDGame ancestor found." % name)
		return

	call_deferred("_initialize")

## Set priority from category (subclass _ready has already run), then call the virtual init hook.
func _initialize() -> void:
	process_physics_priority = CDEnums.category_to_priority(component_category)
	_on_initialize()

## Override to connect game bus signals and set up game-level logic.
func _on_initialize() -> void:
	pass

## --- Bus Connection Tracking ---

## Connect to game bus and track the connection for CDStage sleep/wake.
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

## Override to customize sleep behavior (clear timers, reset state, etc.).
func _on_sleep() -> void:
	set_physics_process(false)

## Override to customize wake behavior (restart timers, re-query state, etc.).
func _on_wake() -> void:
	set_physics_process(true)