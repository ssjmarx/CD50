# CDParabolaCurve
# Parabolic arc curve with configurable curvature power
# Useful for projectile trajectories and bounce paths

@tool
class_name CDParabolaCurve extends CDCurve

# peak displacement from the base path
@export var amplitude: float = 150.0:
	set(v):
		amplitude = v
		emit_changed()

# power exponent controlling the parabola shape (higher = more peaked)
@export var curvature: float = 2.0:
	set(v):
		curvature = v
		emit_changed()

# which side the parabola curves toward (1 or -1)
@export var direction: int = 1:
	set(v):
		direction = v
		emit_changed()

# generate a parabolic arc from start to end
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	# travel direction and perpendicular for displacement
	var travel := (end - start).normalized()
	var perp := Vector2(-travel.y, travel.x) * float(direction)

	# seed-based offset for variation
	var seed_offset := _get_phase() * 0.1

	# sample parabola using powered sin envelope
	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var para := pow(sin(PI * t + seed_offset), curvature) * amplitude
		var pos := base + perp * para

		curve.add_point(pos)

	return _finalize(curve)