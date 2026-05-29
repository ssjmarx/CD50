# CDArcCurve
# Arc / semicircle curve between two points
# Bulges perpendicular to the travel direction with configurable height

@tool
class_name CDArcCurve extends CDCurve

# peak height of the arc perpendicular to travel
@export var height: float = 150.0:
	set(v):
		height = v
		emit_changed()

# which side the arc bulges toward (1 or -1)
@export var bulge_direction: int = 1:
	set(v):
		bulge_direction = v
		emit_changed()

# generate an arc from start to end with seed-based height variation
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# calculate travel direction and perpendicular axis
	var mid := (start + end) * 0.5
	var travel := end - start
	var travel_dir := travel.normalized()
	var perp := Vector2(-travel_dir.y, travel_dir.x) * float(bulge_direction)

	# apply seed-based height variation
	var seed_offset := _get_phase() * 0.1
	var effective_height := height * (1.0 + seed_offset)

	# sample arc points using sin/cos parametric form
	for i in range(resolution + 1):
		var t := float(i) / float(resolution)

		var angle := PI * (1.0 - 2.0 * absf(t - 0.5))
		var forward := -cos(angle)
		var arc := sin(angle) * effective_height

		var pos := mid + travel_dir * (forward * travel.length() * 0.5) + perp * arc
		curve.add_point(pos)

	return _finalize(curve)