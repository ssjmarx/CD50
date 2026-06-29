## cd_sequence_step.gd
## Produces: a single timed step in a signal sequence (signals + wait).
## Consumes: nothing — pure data resource consumed by SignalManager.
class_name CDSequenceStep extends Resource

## game bus signals to fire simultaneously when this step activates
@export var signals: Array[StringName] = []

## seconds to wait after firing before advancing to the next step
@export var delay_after: float = 0.0

## if set, pause after delay_after until this signal fires on the game bus
## useful for synchronizing with spawning/swoop completion
@export var wait_for_signal: StringName = &""

## how many times the wait_for_signal must fire before advancing
@export var wait_count: int = 1