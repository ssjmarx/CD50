@tool

## MarchingOrderBreathe
## A formation order that animates the formation "breathing" (expanding/contracting).
## Controls both the spacing scale (grid expansion) and formation offset scale (distance from center).

class_name MarchingOrderBreathe extends CDMarchingOrder

## --- exports ---

@export_group("Spacing Breathing")
## Amplitude of spacing scale (0 = no breathing, 1.0 = spacing doubles at peak)
@export var spacing_amplitude: float = 0.0
## Duration in seconds for one full breathe-in/breathe-out cycle
@export var spacing_duration: float = 4.0

@export_group("Offset Breathing")
## Amplitude of formation offset expansion (0 = no offset breathing).
## Multiplies the CDFormation's configured offset from center.
@export var offset_amplitude: float = 0.0

## --- public methods ---

func get_duration() -> float:
	return spacing_duration

## Returns breathing data for this frame.
## time: The elapsed time on the current marching order.
func get_breathing_values(time: float) -> Dictionary:
	if spacing_duration <= 0.0:
		return { "spacing_scale": 1.0, "offset_scale": 1.0 }
	
	## Calculate sine wave phase (0 to TAU)
	var phase: float = time / spacing_duration * TAU
	
	## Calculate normalized intensity (0.0 to 1.0)
	## Using (1 - cos) / 2 creates a single smooth wave (0 -> 1 -> 0) over the full period
	var intensity: float = (1.0 - cos(phase)) / 2.0
	
	var spacing_scale: float = 1.0 + intensity * spacing_amplitude
	var offset_scale: float = 1.0 + intensity * offset_amplitude
	
	return { "spacing_scale": spacing_scale, "offset_scale": offset_scale }
