## CDSineCurve
## Sine wave curve — smooth sinusoidal oscillation along travel direction
## Amplitude controls peak displacement, frequency controls wave count

@tool
class_name CDSineCurve extends CDCurve

## peak displacement perpendicular to travel
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

## number of full sine cycles
@export var frequency: int = 1:
	set(v):
		frequency = v
		emit_changed()

## generate a smooth sine wave from start to end
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	var phase := _get_phase()

	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var wave := amplitude * sin(frequency * TAU * t + phase)
		var pos := base + perpendicular * wave

		curve.add_point(pos)

	return _finalize(curve)
