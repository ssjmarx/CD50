# TimedMark
# Tracks how long bodies remain inside the zone with configurable hold duration
# Emits progress ticks during hold and completion when duration is met

class_name TimedMark extends CDMark

# --- exports ---

# time in seconds a body must remain inside to trigger completion
@export var hold_duration: float = 3.0
# interval in seconds between progress tick signals
@export var tick_interval: float = 0.5

# game bus signals for occupy, progress, completion, and vacate
@export_group("Emit Signals")
@export var on_occupy: Array[StringName] = [&"mark_occupied"]
@export var on_progress: Array[StringName] = [&"mark_progress"]
@export var on_complete: Array[StringName] = [&"mark_complete"]
@export var on_vacate: Array[StringName] = [&"mark_vacated"]

# --- state ---

# per-body elapsed time {body: float}
var _occupants: Dictionary = {}
# per-body tick accumulator {body: float}
var _tick_accumulators: Dictionary = {}

# --- processing ---

# advance timers, emit progress ticks, check for completion
func _physics_process(delta: float) -> void:
	var completed: Array[Node2D] = []
	
	for body in _occupants:
		_occupants[body] += delta
		var elapsed: float = _occupants[body]
		
		# emit progress at configured tick interval
		if tick_interval > 0.0:
			_tick_accumulators[body] += delta
			if _tick_accumulators[body] >= tick_interval:
				_tick_accumulators[body] -= tick_interval
				var fraction := elapsed / hold_duration
				for sig in on_progress:
					game.bus_emit(sig, [body, fraction])
		
		# check if hold duration met
		if elapsed >= hold_duration:
			completed.append(body)
			for sig in on_complete:
				game.bus_emit(sig, [body])
	
	# remove completed bodies from tracking
	for body in completed:
		_occupants.erase(body)
		_tick_accumulators.erase(body)

# --- body detection ---

# register body for timing, emit occupy on first entry
func _on_body_entered(body: Node2D) -> void:
	if not _passes_filter(body):
		return
	
	# relay base entered signal
	for sig in on_entered:
		game.bus_emit(sig, [body])
	
	# start timing this body
	var was_empty := _occupants.is_empty()
	_occupants[body] = 0.0
	_tick_accumulators[body] = 0.0
	
	# emit occupy when first body enters an empty zone
	if was_empty:
		for sig in on_occupy:
			game.bus_emit(sig, [body])

# remove body from timing, emit vacate when zone empties
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])
	
	# stop timing this body
	_occupants.erase(body)
	_tick_accumulators.erase(body)
	
	# emit vacate when last body leaves
	if _occupants.is_empty():
		for sig in on_vacate:
			game.bus_emit(sig)
