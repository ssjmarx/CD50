# CDSignalTrigger
# Event trigger — fires when a game bus signal is received
# Captures entity arguments for use by transitions and composite triggers

class_name CDSignalTrigger extends CDTrigger

# bus signal name to listen for
@export var signal_name: StringName = &""

# true when signal has been received, consumed on evaluate()
var _has_fired: bool = false

# entities captured from signal arguments, consumed via consume_pending()
var _pending_entities: Array[CDEntity] = []

# connect to the game bus signal during initialization
func initialize(game: CDGame) -> void:
	super.initialize(game)
	if signal_name != &"":
		game.bus_connect(signal_name, _on_signal_received)
	else:
		push_error("CDSignalTrigger: signal_name is empty — trigger will never fire.")

# return true once per signal received, then auto-reset
func evaluate(_delta: float) -> bool:
	if _has_fired:
		_has_fired = false
		return true
	return false

# return captured entities and clear the internal list
func consume_pending() -> Array[CDEntity]:
	var result: Array[CDEntity] = []
	result.assign(_pending_entities)
	_pending_entities.clear()
	return result

# disconnect from bus and clear all state
func reset() -> void:
	if _game != null and signal_name != &"":
		_game.bus_disconnect(signal_name, _on_signal_received)
	_has_fired = false
	_pending_entities.clear()
	super.reset()

# bus callback — arg1 is the entity (must maintain this convention)
func _on_signal_received(arg1: Variant = null, _arg2: Variant = null) -> void:
	_has_fired = true
	if arg1 is CDEntity:
		_pending_entities.append(arg1)