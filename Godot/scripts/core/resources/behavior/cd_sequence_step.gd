## CDSequenceStep
## A single step in a SignalManager's timed signal sequence
## Fires one or more game bus signals simultaneously, then waits before advancing

class_name CDSequenceStep extends Resource

## --- exports ---

## game bus signals to fire simultaneously when this step activates
@export var signals: Array[StringName] = []

## seconds to wait after firing before advancing to the next step
@export var delay_after: float = 0.0

## if set, pause after delay_after until this signal fires on the game bus
## useful for synchronizing with spawning/swoop completion
@export var wait_for_signal: StringName = &""

## how many times the wait_for_signal must fire before advancing
@export var wait_count: int = 1