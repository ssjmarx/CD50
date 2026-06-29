## marching_order_step.gd
## Produces: a formation step order (linear relative move over duration).
## Consumes: nothing — pure data resource consumed by FormationDirector.
@tool
class_name MarchingOrderStep extends CDMarchingOrder

## the relative offset to apply to the formation center
@export var offset: Vector2 = Vector2.ZERO

## duration of the movement in seconds
@export var duration: float = 2.0

## Return the total step duration.
func get_duration() -> float:
	return duration

## Return the absolute offset achieved at the given time.
func get_offset_at_time(time: float) -> Vector2:
	var t := 1.0
	if duration > 0.0:
		t = clamp(time / duration, 0.0, 1.0)
	return offset * t

## Return the final total offset when this step completes.
func get_accumulated_offset() -> Vector2:
	return offset