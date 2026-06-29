## cd_stage_rule.gd
## Produces: a stage sleep/wake control rule (trigger → named stages + signals).
## Consumes: nothing — pure data resource consumed by StageManager.
class_name CDStageRule extends Resource

## what activates this rule (signal, timer, etc.)
@export var trigger: CDTrigger

## stage node names to put to sleep
@export var sleep_stages: Array[StringName] = []

## stage node names to wake up
@export var wake_stages: Array[StringName] = []

## game bus signals to emit after execution
@export var game_signals: Array[StringName] = []

## Initialize trigger with game reference.
func initialize(game: CDGame) -> void:
	if trigger:
		trigger.initialize(game)

## Full reset for game restart.
func reset() -> void:
	if trigger:
		trigger.reset()

## At least one stage target or signal must be set.
func is_valid() -> bool:
	return not sleep_stages.is_empty() or not wake_stages.is_empty() or not game_signals.is_empty()