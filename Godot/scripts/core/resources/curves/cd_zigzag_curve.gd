@tool

## zigzag curve
class_name CDZigzagCurve extends CDCurve

@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

@export var segments: int = 4:
	set(v):
		segments = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var sign_flip := 1.0 if sin(_get_phase()) >= 0.0 else -1.0
	var total_peaks := segments * 2

	curve.add_point(start)

	for i in range(1, total_peaks + 1):
		var t := float(i) / float(total_peaks + 1)
		var base := _base_position(start, end, t)

		var zig_sign := sign_flip * (1.0 if i % 2 != 0 else -1.0)
		var pos := base + perpendicular * amplitude * zig_sign

		curve.add_point(pos)

	curve.add_point(start)

	return _finalize(curve)