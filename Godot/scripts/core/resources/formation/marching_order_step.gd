@tool

## MarchingOrderStep
## Defines a physical movement of the formation by a relative offset over a duration.

class_name MarchingOrderStep extends CDMarchingOrder

## --- exports ---

## the relative offset to apply to the formation center
@export var offset: Vector2 = Vector2.ZERO

## duration of the movement in seconds
@export var duration: float = 2.0

## --- public methods ---

func get_duration() -> float:
	return duration

func get_offset_at_time(time: float) -> Vector2:
	var t := 1.0
	if duration > 0.0:
		t = clamp(time / duration, 0.0, 1.0)
	return offset * t

func get_accumulated_offset() -> Vector2:
	return offset
