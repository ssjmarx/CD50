## SignalManager
## Produces: a timed sequence of game bus signals from one trigger signal.
## Consumes: game bus trigger signal + CDManagerStep resources.

class_name SignalManager extends CDGameComponent

## --- exports ---

@export_group("Sequence")
## ordered steps to execute when the sequence triggers
@export var steps: Array[CDSequenceStep] = []

@export_group("Trigger")
## what activates this sequence (signal, timer, etc.)
@export var trigger: CDTrigger

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

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.MANAGER
	super._ready()
	set_physics_process(false)

func _on_initialize() -> void:
	if trigger:
		trigger.initialize(game)

## --- processing ---

## poll trigger each frame, tick the delay/wait timer when running
func _physics_process(delta: float) -> void:
	## idle: poll the trigger to (re)start the sequence
	if not _running:
		if trigger and trigger.evaluate(delta):
			_start_sequence()
		return

	## waiting on a sync signal: hold the delay countdown
	if _waiting_for_signal:
		return

	## count down the delay to the next step
	_delay_remaining -= delta
	if _delay_remaining <= 0.0:
		_delay_remaining = 0.0
		_advance()

## start the sequence
func _start_sequence() -> void:
	if steps.is_empty():
		return
	_running = true
	_current_step = 0
	_execute_step()

## --- step execution ---

## fire the current step's signals and enter delay/wait phase
func _execute_step() -> void:
	var step: CDSequenceStep = steps[_current_step]

	## emit every signal declared on this step
	for sig in step.signals:
		if sig != &"":
			game.bus_emit(sig)

	## arm the delay timer for this step
	_delay_remaining = step.delay_after

	## if a sync gate is configured, subscribe and wait for it
	if step.wait_for_signal != &"" and step.wait_count > 0:
		_signal_fire_count = 0
		_waiting_for_signal = true
		bus_connect(step.wait_for_signal, _on_sync_signal)
	else:
		_waiting_for_signal = false

	## neither delay nor gate: advance at once
	if _delay_remaining <= 0.0 and not _waiting_for_signal:
		_advance()
	else:
		set_physics_process(true)

## called when delay expires — either advances or waits for sync
func _advance() -> void:
	if _waiting_for_signal:
		return  ## will advance when sync signal fires
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
		## tear down the sync subscription now that the gate is satisfied
		var sync_sig: StringName = steps[_current_step].wait_for_signal
		game.bus_disconnect(sync_sig, _on_sync_signal)
		_waiting_for_signal = false
		## if the delay already elapsed, advance; else wait it out
		if _delay_remaining <= 0.0:
			_next_step()

## disconnect the current step's sync listener if still connected (defensive cleanup)
func _disconnect_sync_listener() -> void:
	if _waiting_for_signal and _current_step >= 0 and _current_step < steps.size():
		var sync_sig: StringName = steps[_current_step].wait_for_signal
		if sync_sig != &"" and game.has_signal(sync_sig) and game.is_connected(sync_sig, _on_sync_signal):
			game.bus_disconnect(sync_sig, _on_sync_signal)
	_waiting_for_signal = false

## defensively disconnect any lingering sync listener, emit completion signals, stop processing
func _complete() -> void:
	_disconnect_sync_listener()
	_running = false
	_current_step = -1
	set_physics_process(false)
	for sig in on_sequence_complete:
		if sig != &"":
			game.bus_emit(sig)

## reset sequence state for game restart
func reset() -> void:
	_disconnect_sync_listener()
	_running = false
	_current_step = -1
	_delay_remaining = 0.0
	_waiting_for_signal = false
	_signal_fire_count = 0
	set_physics_process(false)
	if trigger:
		trigger.reset()
