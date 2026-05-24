## emits while a body remains inside the zone for a configured duration
class_name TimedMark extends CDMark

@export var hold_duration: float = 3.0
@export var tick_interval: float = 0.5

@export_group("Emit Signals")
@export var on_occupy: Array[StringName] = [&"mark_occupied"]
@export var on_progress: Array[StringName] = [&"mark_progress"]
@export var on_complete: Array[StringName] = [&"mark_complete"]
@export var on_vacate: Array[StringName] = [&"mark_vacated"]


var _occupants: Dictionary = {} # {body: elapsed_time}
var _tick_accumulators: Dictionary = {} # {body: accumulated_tick_time}

## advances timers, checks for completion
func _physics_process(delta: float) -> void:
	var completed: Array[Node2D] = []
	
	for body in _occupants:
		_occupants[body] += delta
		
		var elapsed: float = _occupants[body]
		
		if tick_interval > 0.0:
			_tick_accumulators[body] += delta
			if _tick_accumulators[body] >= tick_interval:
				_tick_accumulators[body] -= tick_interval
				var fraction := elapsed / hold_duration
				for sig in on_progress:
					game.bus_emit(sig, [body, fraction])
		
		if elapsed >= hold_duration:
			completed.append(body)
			for sig in on_complete:
				game.bus_emit(sig, [body])
	
	for body in completed:
		_occupants.erase(body)
		_tick_accumulators.erase(body)

## registers all bodies that enter the mark
func _on_body_entered(body: Node2D) -> void:
	if not _passes_filter(body):
		return
	
	for sig in on_entered:
		game.bus_emit(sig, [body])
	
	var was_empty := _occupants.is_empty()
	_occupants[body] = 0.0
	_tick_accumulators[body] = 0.0
	
	if was_empty:
		for sig in on_occupy:
			game.bus_emit(sig, [body])

## deregisters all bodies that leave the mark
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])
	
	_occupants.erase(body)
	_tick_accumulators.erase(body)
	
	if _occupants.is_empty():
		for sig in on_vacate:
			game.bus_emit(sig)
