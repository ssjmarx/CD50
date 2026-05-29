@tool

## spiral curve
class_name CDSpiralCurve extends CDCurve

@export var max_radius: float = 150.0:
	set(v):
		max_radius = v
		emit_changed()

@export var turns: int = 3:
	set(v):
		turns = v
		emit_changed()

@export var inward: bool = true:
	set(v):
		inward = v
		emit_changed()

func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var travel_dir := (end - start).normalized()
	var perp := Vector2(-travel_dir.y, travel_dir.x)

	var phase := _get_phase()

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var angle := turns * TAU * t + phase

		var depth := sin(PI * t)
		var r: float
		if inward:
			r = max_radius * (1.0 - depth * 0.8)
		else:
			r = max_radius * depth

		var pos := base + perp * cos(angle) * r + travel_dir * (sin(angle) * r * 0.3)

		curve.add_point(pos)

	return _finalize(curve)
