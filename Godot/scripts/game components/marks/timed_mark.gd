## TimedMark
## Tracks how long bodies remain inside the zone with configurable hold duration
## Emits progress ticks during hold and completion when duration is met

class_name TimedMark extends CDMark

## --- exports ---

## time in seconds a body must remain inside to trigger completion
@export var hold_duration: float = 3.0
## interval in seconds between progress tick signals
@export var tick_interval: float = 0.5

@export_group("Blackboard Keys")
## key for writing the body that triggered progress/complete/occupy (Node2D)
@export var active_body_key: StringName = &"mark_active_body"
## key for writing the progress fraction (float, 0.0–1.0)
@export var progress_fraction_key: StringName = &"mark_progress_fraction"

## game bus signals for occupy, progress, completion, and vacate (zero-arg)
@export_group("Emit Signals")
@export var on_occupy: Array[StringName] = [&"mark_occupied"]
@export var on_progress: Array[StringName] = [&"mark_progress"]
@export var on_complete: Array[StringName] = [&"mark_complete"]
@export var on_vacate: Array[StringName] = [&"mark_vacated"]

## --- state ---

## per-body elapsed time {body: float}
var _occupants: Dictionary = {}
## per-body tick accumulator {body: float}
var _tick_accumulators: Dictionary = {}

## --- processing ---

## advance timers, write to blackboard, emit zero-arg signals
func _physics_process(delta: float) -> void:
	var completed: Array[Node2D] = []

	for body in _occupants:
		_occupants[body] += delta
		var elapsed: float = _occupants[body]

		## emit progress at configured tick interval
		if tick_interval > 0.0:
			_tick_accumulators[body] += delta
			if _tick_accumulators[body] >= tick_interval:
				_tick_accumulators[body] -= tick_interval
				var fraction := elapsed / hold_duration
				game.blackboard[active_body_key] = body
				game.blackboard[progress_fraction_key] = fraction
				for sig in on_progress:
					game.bus_emit(sig)

		## check if hold duration met
		if elapsed >= hold_duration:
			completed.append(body)
			game.blackboard[active_body_key] = body
			for sig in on_complete:
				game.bus_emit(sig)

	for body in completed:
		_occupants.erase(body)
		_tick_accumulators.erase(body)

## --- body detection ---

## register body for timing, write to blackboard, emit zero-arg occupy
func _on_body_entered(body: Node2D) -> void:
	if not _passes_filter(body):
		return

	game.blackboard[entered_body_key] = body
	for sig in on_entered:
		game.bus_emit(sig)

	var was_empty := _occupants.is_empty()
	_occupants[body] = 0.0
	_tick_accumulators[body] = 0.0

	## emit occupy when first body enters an empty zone
	if was_empty:
		game.blackboard[active_body_key] = body
		for sig in on_occupy:
			game.bus_emit(sig)

## remove body from timing, emit zero-arg vacate when zone empties
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		game.blackboard[exited_body_key] = body
		for sig in on_exited:
			game.bus_emit(sig)

	_occupants.erase(body)
	_tick_accumulators.erase(body)

	if _occupants.is_empty():
		for sig in on_vacate:
			game.bus_emit(sig)
