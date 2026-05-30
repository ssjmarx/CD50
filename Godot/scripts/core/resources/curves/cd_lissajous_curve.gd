# CDLissajousCurve
# Lissajous figure curve — sin/cos oscillation with independent axes
# Classic interference pattern with seed-based phase offset

@tool
class_name CDLissajousCurve extends CDCurve

# horizontal oscillation amplitude
@export var amplitude_x: float = 150.0:
	set(v):
		amplitude_x = v
		emit_changed()

# vertical oscillation amplitude
@export var amplitude_y: float = 200.0:
	set(v):
		amplitude_y = v
		emit_changed()

# frequency multiplier for the pattern
@export var loops: int = 1:
	set(v):
		loops = v
		emit_changed()

# generate a Lissajous figure along the base path
func generate_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve := Curve2D.new()
	var phase := _get_phase()

	# sin on X, cos on Y creates classic Lissajous interference
	for i in range(resolution + 1):
		var t := float(i) / float(resolution)
		var base := _base_position(start, end, t)

		var x := base.x + amplitude_x * sin(loops * TAU * t + phase)
		var y := base.y + amplitude_y * cos(loops * TAU * t + phase)

		curve.add_point(Vector2(x, y))

	return _finalize(curve)
