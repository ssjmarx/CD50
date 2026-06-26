@tool

## MarchingOrderPause
## Defines a wait time for the formation at its current position.

class_name MarchingOrderPause extends CDMarchingOrder

## --- exports ---

## duration of the pause in seconds
@export var duration: float = 1.0

## --- public methods ---

func get_duration() -> float:
	return duration
