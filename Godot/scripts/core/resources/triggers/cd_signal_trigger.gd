## event trigger: fires when a game bus signal is received.
class_name CDSignalTrigger extends CDTrigger

@export var signal_name: StringName = &""

var _has_fired: bool = false
var _pending_entities: Array[CDEntity] = []

func initialize(game: CDGame) -> void:
	super.initialize(game)
	if signal_name != &"":
		game.bus_connect(signal_name, _on_signal_received)
	else:
		push_error("CDSignalTrigger: signal_name is empty — trigger will never fire.")

func evaluate(_delta: float) -> bool:
	if _has_fired:
		_has_fired = false
		return true
	return false

## returns pending entities and clears the internal list.
func consume_pending() -> Array[CDEntity]:
	var result: Array[CDEntity] = []
	result.assign(_pending_entities)
	_pending_entities.clear()
	return result

func reset() -> void:
	if _game != null and signal_name != &"":
		_game.bus_disconnect(signal_name, _on_signal_received)
	_has_fired = false
	_pending_entities.clear()
	super.reset()

## arg1 is the entity, have to maintain this convention
func _on_signal_received(arg1: Variant = null, _arg2: Variant = null) -> void:
	_has_fired = true
	if arg1 is CDEntity:
		_pending_entities.append(arg1)
