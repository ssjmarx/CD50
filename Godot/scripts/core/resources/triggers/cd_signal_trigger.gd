# CDSignalTrigger
# Event trigger — fires when game bus signal(s) are received
# Captures entity arguments for use by transitions and composite triggers
# Supports require_all: true = all signals must be received before firing

class_name CDSignalTrigger extends CDTrigger

# bus signal names to listen for
@export var signal_names: Array[StringName] = []

# true = all signals must be received before firing; false = any signal fires immediately
@export var require_all: bool = false

# true when trigger should fire, consumed on evaluate()
var _has_fired: bool = false

# entities captured from signal arguments, consumed via consume_pending()
var _pending_entities: Array[CDEntity] = []

# tracks which signals have been received (for require_all mode)
var _received: Dictionary = {}

# connect to all game bus signals during initialization
func initialize(game: CDGame) -> void:
	super.initialize(game)
	for sig in signal_names:
		if sig != &"":
			game.bus_connect(sig, _on_signal_received.bind(sig))
	if signal_names.is_empty():
		push_warning("CDSignalTrigger: signal_names is empty — trigger will never fire.")

# return true once per fire, then auto-reset
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
	if _game != null:
		for sig in signal_names:
			if sig != &"":
				_game.bus_disconnect(sig, _on_signal_received.bind(sig))
	_has_fired = false
	_pending_entities.clear()
	_received.clear()
	super.reset()

# bus callback — capture entity from arg1, track which signal was received
func _on_signal_received(arg1: Variant = null, _arg2: Variant = null, signal_name: StringName = &"") -> void:
	if arg1 is CDEntity:
		_pending_entities.append(arg1)
	
	if require_all:
		# track that this specific signal has been received
		_received[signal_name] = true
		if _received.size() >= signal_names.size():
			_has_fired = true
			_received.clear()
	else:
		_has_fired = true
