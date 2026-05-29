@tool

## triangle "curve"
class_name CDTriangleCurve extends CDCurve

@export var size: float = 100.0:
	set(v):
		size = v
		emit_changed()

@export var base_angle: float = 60.0:
	set(v):
		base_angle = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var direction := (start - end).normalized()

	var apex_deg := 180.0 - 2.0 * clampf(base_angle, 1.0, 89.0)
	var apex_rad := deg_to_rad(apex_deg)

	var rotation := _get_phase()

	var v0 := end

	var base_dir := -direction.rotated(rotation)
	var v1 := v0 + base_dir.rotated(apex_rad / 2.0) * size
	var v2 := v0 + base_dir.rotated(-apex_rad / 2.0) * size

	curve.add_point(v0)
	curve.add_point(v1)
	curve.add_point(v2)
	curve.add_point(v0)

	return _finalize(curve)