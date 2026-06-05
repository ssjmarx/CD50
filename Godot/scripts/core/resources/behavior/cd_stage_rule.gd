## CDStageRule
## Defines a single stage control rule for StageManager
## When the trigger fires, named CDStages are slept/woken and optional game signals emitted

class_name CDStageRule extends Resource

## --- Exports ---

## what activates this rule (signal, timer, etc.)
@export var trigger: CDTrigger

## stage node names to put to sleep
@export var sleep_stages: Array[StringName] = []

## stage node names to wake up
@export var wake_stages: Array[StringName] = []

## game bus signals to emit after execution
@export var game_signals: Array[StringName] = []

## --- Lifecycle ---

## initialize trigger with game reference
func initialize(game: CDGame) -> void:
	if trigger:
		trigger.initialize(game)

## full reset for game restart
func reset() -> void:
	if trigger:
		trigger.reset()

## --- Validation ---

## at least one stage target or signal must be set
func is_valid() -> bool:
	return not sleep_stages.is_empty() or not wake_stages.is_empty() or not game_signals.is_empty()