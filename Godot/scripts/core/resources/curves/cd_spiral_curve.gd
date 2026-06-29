## cd_spiral_curve.gd
## Produces: a spiral curve with depth-modulated radius along the base path.
## Consumes: nothing — pure data resource consumed by curve users (Legs).
@tool
class_name CDSpiralCurve extends CDCurve

## maximum spiral radius
@export var max_radius: float = 150.0:
	set(v):
		max_radius = v
		emit_changed()

## number of spiral rotations
@export var turns: int = 3:
	set(v):
		turns = v
		emit_changed()

## true = spiral tightens inward, false = expands outward
@export var inward: bool = true:
	set(v):
		inward = v
		emit_changed()

## generate a spiral path from start to end with depth-modulated radius
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var travel_dir := (end - start).normalized()
	var perp := Vector2(-travel_dir.y, travel_dir.x)

	var phase := _get_phase()

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var angle := turns * TAU * t + phase

		## depth factor peaks in the middle of the path
		var depth := sin(PI * t)
		var r: float
		if inward:
			r = max_radius * (1.0 - depth * 0.8)
		else:
			r = max_radius * depth

		var pos := base + perp * cos(angle) * r + travel_dir * (sin(angle) * r * 0.3)

		curve.add_point(pos)

	return _finalize(curve)
