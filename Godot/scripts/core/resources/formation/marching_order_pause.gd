## marching_order_pause.gd
## Produces: a formation hold/pause order (waits at current position).
## Consumes: nothing — pure data resource consumed by FormationDirector.
@tool
class_name MarchingOrderPause extends CDMarchingOrder

## duration of the pause in seconds
@export var duration: float = 1.0

## Return the total pause duration.
func get_duration() -> float:
	return duration