# CDTriangleCurve
# Triangle shape — closed 3-vertex polygon
# Apex angle derived from base_angle; seed phase rotates the shape

@tool
class_name CDTriangleCurve extends CDCurve

# side length of the triangle
@export var size: float = 100.0:
	set(v):
		size = v
		emit_changed()

# base angle in degrees (clamped 1–89); apex = 180 - 2 * base_angle
@export var base_angle: float = 60.0:
	set(v):
		base_angle = v
		emit_changed()

# generate a closed triangle from end point outward
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# direction from end back toward start (base direction)
	var direction := (start - end).normalized()

	# apex angle derived from base angle constraint
	var apex_deg := 180.0 - 2.0 * clampf(base_angle, 1.0, 89.0)
	var apex_rad := deg_to_rad(apex_deg)

	# seed-based rotation for variation
	var rotation := _get_phase()

	# three vertices: base point + two arms spread by apex angle
	var v0 := end

	var base_dir := -direction.rotated(rotation)
	var v1 := v0 + base_dir.rotated(apex_rad / 2.0) * size
	var v2 := v0 + base_dir.rotated(-apex_rad / 2.0) * size

	curve.add_point(v0)
	curve.add_point(v1)
	curve.add_point(v2)
	curve.add_point(v0)

	return _finalize(curve)