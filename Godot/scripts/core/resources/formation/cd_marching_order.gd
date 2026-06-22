## CDMarchingOrder
## Base class for formation movement commands.
## Subclasses define specific behaviors (Step, Pause, Breathe).

class_name CDMarchingOrder extends Resource

## Returns breathing data for this frame.
## Only subclasses that support breathing should override this.
## Returns a Dictionary with keys "spacing_scale" (float) and "offset_scale" (float).
func get_breathing_values(_time: float) -> Dictionary:
	return { "spacing_scale": 1.0, "offset_scale": 1.0 }
