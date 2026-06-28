## SignalSequenceDirector
## Data-driven signal macro — turns one trigger signal into a timed sequence of game bus signals
## Each step fires its signals, waits a delay, optionally waits for a sync signal, then advances

@tool
class_name SignalSequenceDirector extends CDGameComponent

## --- exports ---

@export_group("Sequence")
## ordered steps to execute when the sequence triggers
@export var steps: Array[CDSequenceStep] = []

@export_group("Trigger")
## game bus signals that start the sequence
@export var trigger_signals: Array[StringName] = [&"game_play"]

@export_group("Completion")
## game bus signals emitted when the entire sequence finishes
@export var on_sequence_complete: Array[StringName] = [&"sequence_complete"]

## --- state ---

## current step index (-1 = not running)
var _current_step: int = -1

## countdown timer for delay_after
var _delay_remaining: float = 0.0

## are we waiting for a sync signal?
var _waiting_for_signal: bool = false

## how many times the sync signal has fired this step
var _signal_fire_count: int = 0

## is the sequence actively running?
var _running: bool = false

## --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()
	set_physics_process(false)

func _on_initialize() -> void:
	connect_all(trigger_signals, _on_trigger)

## --- trigger ---

## start the sequence
func _on_trigger() -> void:
	if _running:
		return
	if steps.is_empty():
		return
	_running = true
	_current_step = 0
	_execute_step()

## --- processing ---

## tick the delay/wait timer each frame
func _physics_process(delta: float) -> void:
	if not _running:
		set_physics_process(false)
		return

	# if waiting for sync signal, only tick delay (if not already elapsed)
	if _waiting_for_signal:
		return

	# count down delay
	_delay_remaining -= delta
	if _delay_remaining <= 0.0:
		_delay_remaining = 0.0
		_advance()

## --- step execution ---

## fire the current step's signals and enter delay/wait phase
func _execute_step() -> void:
	var step: CDSequenceStep = steps[_current_step]

	# fire all signals for this step
	for sig in step.signals:
		if sig != &"":
			game.bus_emit(sig)

	# set delay timer
	_delay_remaining = step.delay_after

	# if step has a sync signal, set up wait
	if step.wait_for_signal != &"" and step.wait_count > 0:
		_signal_fire_count = 0
		_waiting_for_signal = true
		bus_connect(step.wait_for_signal, _on_sync_signal)
	else:
		_waiting_for_signal = false

	# if no delay and no wait, advance immediately
	if _delay_remaining <= 0.0 and not _waiting_for_signal:
		_advance()
	else:
		set_physics_process(true)

## called when delay expires — either advances or waits for sync
func _advance() -> void:
	if _waiting_for_signal:
		return  # will advance when sync signal fires
	_next_step()

## move to the next step or complete the sequence
func _next_step() -> void:
	_current_step += 1
	if _current_step >= steps.size():
		_complete()
	else:
		_execute_step()

## --- sync signal handling ---

## count sync signal fires and advance when threshold met
func _on_sync_signal() -> void:
	_signal_fire_count += 1
	if _signal_fire_count >= steps[_current_step].wait_count:
		# disconnect sync listener
		var sync_sig: StringName = steps[_current_step].wait_for_signal
		game.bus_disconnect(sync_sig, _on_sync_signal)
		_waiting_for_signal = false
		# if delay also expired, advance; otherwise wait for delay
		if _delay_remaining <= 0.0:
			_next_step()

## --- completion ---

## defensively disconnect any lingering sync listener, emit completion signals, stop processing
func _complete() -> void:
	_disconnect_sync_listener()
	_running = false
	_current_step = -1
	set_physics_process(false)
	for sig in on_sequence_complete:
		if sig != &"":
			game.bus_emit(sig)

## --- sync signal handling helpers ---

## disconnect the current step's sync listener if still connected (defensive cleanup)
func _disconnect_sync_listener() -> void:
	if _waiting_for_signal and _current_step >= 0 and _current_step < steps.size():
		var sync_sig: StringName = steps[_current_step].wait_for_signal
		if sync_sig != &"" and game.has_signal(sync_sig) and game.is_connected(sync_sig, _on_sync_signal):
			game.bus_disconnect(sync_sig, _on_sync_signal)
	_waiting_for_signal = false

## --- reset ---

## reset sequence state for game restart
func reset() -> void:
	_disconnect_sync_listener()
	_running = false
	_current_step = -1
	_delay_remaining = 0.0
	_waiting_for_signal = false
	_signal_fire_count = 0
	set_physics_process(false)
