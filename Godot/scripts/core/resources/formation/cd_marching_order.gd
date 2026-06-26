## CDMarchingOrder
## Base class for formation movement commands.
## Subclasses define specific behaviors (Step, Pause, Breathe, Repeat).

class_name CDMarchingOrder extends Resource

## Returns the total duration of this marching order.
func get_duration() -> float:
	return 0.0

## Returns the absolute offset achieved at the given time.
func get_offset_at_time(_time: float) -> Vector2:
	return Vector2.ZERO

## Returns the final total offset when this order completes.
func get_accumulated_offset() -> Vector2:
	return Vector2.ZERO

## Returns breathing data for this frame.
## Only subclasses that support breathing should override this.
## Returns a Dictionary with keys "spacing_scale" (float) and "offset_scale" (float).
func get_breathing_values(_time: float) -> Dictionary:
	return { "spacing_scale": 1.0, "offset_scale": 1.0 }
