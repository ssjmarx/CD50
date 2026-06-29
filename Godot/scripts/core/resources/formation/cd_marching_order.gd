## cd_marching_order.gd
## Produces: an abstract base contract for formation movement commands.
## Consumes: nothing — base class; subclasses produce offset/breathing data.
class_name CDMarchingOrder extends Resource

## Return the total duration of this marching order.
func get_duration() -> float:
	return 0.0

## Return the absolute offset achieved at the given time.
func get_offset_at_time(_time: float) -> Vector2:
	return Vector2.ZERO

## Return the final total offset when this order completes.
func get_accumulated_offset() -> Vector2:
	return Vector2.ZERO

## Return breathing data (spacing_scale, offset_scale) for this frame.
func get_breathing_values(_time: float) -> Dictionary:
	return { "spacing_scale": 1.0, "offset_scale": 1.0 }