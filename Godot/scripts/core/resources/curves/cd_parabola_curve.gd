@tool

## parabolic curve
class_name CDParabolaCurve extends CDCurve

@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

@export var curvature: float = 2.0:
	set(v):
		curvature = v
		emit_changed()

@export var direction: int = 1:
	set(v):
		direction = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var travel := (end - start).normalized()
	var perp := Vector2(-travel.y, travel.x) * float(direction)

	var seed_offset := _get_phase() * 0.1

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var para := pow(sin(PI * t + seed_offset), curvature) * amplitude
		var pos := base + perp * para

		curve.add_point(pos)

	return _finalize(curve)
