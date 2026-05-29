@tool

## circle/ellipse curve
class_name CDCircleCurve extends CDCurve

@export var radius_x: float = 100.0:
	set(v):
		radius_x = v
		emit_changed()

@export var radius_y: float = 100.0:
	set(v):
		radius_y = v
		emit_changed()

@export var loops: int = 1:
	set(v):
		loops = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	var center := end
	var phase := _get_phase()
	var start_angle := (start - center).angle()

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var angle := start_angle + loops * TAU * t + phase

		var x := center.x + radius_x * cos(angle)
		var y := center.y + radius_y * sin(angle)

		curve.add_point(Vector2(x, y))

	return _finalize(curve)