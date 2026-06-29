## cd_helix_curve.gd
## Produces: a corkscrew/helix curve oscillating around the base path.
## Consumes: nothing — pure data resource consumed by curve users (Legs).
@tool
class_name CDHelixCurve extends CDCurve

## helix radius perpendicular to travel direction
@export var radius: float = 100.0:
	set(v):
		radius = v
		emit_changed()

## number of corkscrew rotations
@export var turns: int = 3:
	set(v):
		turns = v
		emit_changed()

## generate a corkscrew path from start to end
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()

	var travel := end - start
	var travel_dir := travel.normalized()
	var perp := Vector2(-travel_dir.y, travel_dir.x)

	var phase := _get_phase()

	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var angle := turns * TAU * t + phase
		var offset_x := cos(angle) * radius
		var offset_y := sin(angle) * radius

		var pos := base + perp * offset_x + travel_dir * (offset_y * 0.3)
		curve.add_point(pos)

	return _finalize(curve)
