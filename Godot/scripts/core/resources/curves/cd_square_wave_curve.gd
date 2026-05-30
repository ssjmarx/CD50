# CDSquareWaveCurve
# Square wave curve — sharp 90° transitions between high and low
# Returns to start point (closed loop)

@tool
class_name CDSquareWaveCurve extends CDCurve

# peak displacement from the base path
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

# number of square wave steps
@export var steps: int = 4:
	set(v):
		steps = v
		emit_changed()

# generate alternating high/low steps from start back to start
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# perpendicular axis and seed-based side flip
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var sign_flip := 1.0 if sin(_get_phase()) >= 0.0 else -1.0

	var total_half_steps := steps * 2

	curve.add_point(start)

	# alternate between high and low sides with vertical transitions
	for i in range(total_half_steps):
		var t := float(i + 1) / float(total_half_steps + 1)
		var base := _base_position(start, end, t)

		var side := sign_flip * (1.0 if i % 2 == 0 else -1.0)

		curve.add_point(base + perpendicular * amplitude * side)

		# add transition point on the opposite side (vertical step)
		if i < total_half_steps - 1:
			curve.add_point(base + perpendicular * amplitude * (-side))

	curve.add_point(start)

	return _finalize(curve)
