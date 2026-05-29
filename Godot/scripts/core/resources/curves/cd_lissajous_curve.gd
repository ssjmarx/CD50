@tool

## Lissajous curve
class_name CDLissajousCurve extends CDCurve

@export var amplitude_x: float = 150.0:
	set(v):
		amplitude_x = v
		emit_changed()

@export var amplitude_y: float = 200.0:
	set(v):
		amplitude_y = v
		emit_changed()

@export var loops: int = 1:
	set(v):
		loops = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	var phase := _get_phase()

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var x := base.x + amplitude_x * sin(loops * TAU * t + phase)
		var y := base.y + amplitude_y * cos(loops * TAU * t + phase)

		curve.add_point(Vector2(x, y))

	return _finalize(curve)
