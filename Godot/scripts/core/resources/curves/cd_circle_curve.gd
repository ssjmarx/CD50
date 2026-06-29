## cd_circle_curve.gd
## Produces: a circle/ellipse curve centered on end (start sets initial angle).
## Consumes: nothing — pure data resource consumed by curve users (Legs).
@tool
class_name CDCircleCurve extends CDCurve

## horizontal radius (different from radius_y creates an ellipse)
@export var radius_x: float = 100.0:
	set(v):
		radius_x = v
		emit_changed()

## vertical radius
@export var radius_y: float = 100.0:
	set(v):
		radius_y = v
		emit_changed()

## number of full rotations around the center
@export var loops: int = 1:
	set(v):
		loops = v
		emit_changed()

## generate a circle/ellipse centered on end, starting from direction of start
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
