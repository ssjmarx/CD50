## CDSignalTrigger
## Evaluates true when a signal on its list fires
## Used to activate configurable behavior on eg state director

class_name CDSignalTrigger extends CDTrigger

@export var signal_names: Array[StringName] = []
@export var require_all: bool = false
@export var require_count: int = 1

var _has_fired: bool = false
var _received: Dictionary = {}   # {StringName: bool}
var _fire_count: int = 0  

## initialize
func initialize(game: CDGame) -> void:
	super.initialize(game)
	for sig in signal_names:
		if sig != &"":
			game.bus_connect(sig, _on_signal_received.bind(sig))
	if signal_names.is_empty():
		push_warning("CDSignalTrigger: signal_names is empty — trigger will never fire.")

## evaluate
func evaluate(_delta: float) -> bool:
	if _has_fired:
		_has_fired = false
		return true
	return false

## reset
func reset() -> void:
	if _game != null:
		for sig in signal_names:
			if sig != &"":
				_game.bus_disconnect(sig, _on_signal_received.bind(sig))
	_has_fired = false
	_received.clear()
	_fire_count = 0
	super.reset()

## on signal received
func _on_signal_received(signal_name: StringName = &"") -> void:
	_fire_count += 1
	_received[signal_name] = true
	
	var count_met: bool = _fire_count >= require_count
	var all_met: bool = not require_all or _received.size() >= signal_names.size()
	
	if count_met and all_met:
		_has_fired = true
		_received.clear()
		_fire_count = 0
