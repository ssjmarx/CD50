# CDZigzagCurve
# Zigzag curve — alternating sharp peaks on each side of the base path
# Returns to start point (closed loop)

@tool
class_name CDZigzagCurve extends CDCurve

# peak displacement from the base path
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

# number of zigzag peak segments
@export var segments: int = 4:
	set(v):
		segments = v
		emit_changed()

# generate alternating sharp peaks from start back to start
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# perpendicular axis and seed-based side flip
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var sign_flip := 1.0 if sin(_get_phase()) >= 0.0 else -1.0

	var total_peaks := segments * 2

	curve.add_point(start)

	# alternate peaks on each side of the base path
	for i in range(1, total_peaks + 1):
		var t := float(i) / float(total_peaks + 1)
		var base := _base_position(start, end, t)

		var zig_sign := sign_flip * (1.0 if i % 2 != 0 else -1.0)
		var pos := base + perpendicular * amplitude * zig_sign

		curve.add_point(pos)

	curve.add_point(start)

	return _finalize(curve)