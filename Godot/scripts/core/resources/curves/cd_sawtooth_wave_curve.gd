# CDSawtoothWaveCurve
# Sawtooth wave — sharp alternating peaks along the travel path
# Returns to start point (closed loop)

@tool
class_name CDSawtoothWaveCurve extends CDCurve

# peak displacement from the base path
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

# number of sawtooth peaks
@export var teeth: int = 4:
	set(v):
		teeth = v
		emit_changed()

# generate alternating sharp peaks from start back to start
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# calculate perpendicular axis and seed-based side flip
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var sign_flip := 1.0 if sin(_get_phase()) >= 0.0 else -1.0

	curve.add_point(start)

	# generate alternating peaks on each side of the path
	var total_segments := teeth * 2
	for i in range(total_segments):
		var t := float(i + 1) / float(total_segments + 1)
		var base := _base_position(start, end, t)

		var side := sign_flip * (1.0 if i % 2 == 0 else -1.0)
		curve.add_point(base + perpendicular * amplitude * side)

	curve.add_point(start)

	return _finalize(curve)
