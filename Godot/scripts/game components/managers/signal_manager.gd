## SignalManager
## Data-driven signal macro — turns one trigger into a timed sequence of game bus signals
## Each step fires its signals, waits a delay, optionally waits for a sync signal, then advances

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

## --- lifecycle ---

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
	# poll trigger to start sequence
	if not _running:
		if trigger and trigger.evaluate(delta):
			_start_sequence()
		return

	# if waiting for sync signal, don't tick delay
	if _waiting_for_signal:
		return

	# count down delay
	_delay_remaining -= delta
	if _delay_remaining <= 0.0:
		_delay_remaining = 0.0
		_advance()

## --- sequence control ---

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

## emit completion signals and stop processing
func _complete() -> void:
	_running = false
	_current_step = -1
	set_physics_process(false)
	for sig in on_sequence_complete:
		if sig != &"":
			game.bus_emit(sig)

## --- reset ---

## reset sequence state for game restart
func reset() -> void:
	_running = false
	_current_step = -1
	_delay_remaining = 0.0
	_waiting_for_signal = false
	_signal_fire_count = 0
	set_physics_process(false)
	if trigger:
		trigger.reset()