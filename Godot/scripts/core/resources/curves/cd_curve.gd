## CDCurve
## Abstract base class for all path curve resources
## Provides shared exports (resolution, seed, offset, reverse) and utility methods

@tool
class_name CDCurve extends Resource

## number of sample points along the generated curve
@export var resolution: int = 100:
	set(v):
		resolution = v
		emit_changed()

## phase offset seed — non-zero adds per-instance variation
@export var curve_seed: int = 0:
	set(v):
		curve_seed = v
		emit_changed()

## global position offset applied to all points after generation
@export var offset: Vector2 = Vector2.ZERO:
	set(v):
		offset = v
		emit_changed()

## reverse point order in the generated curve
@export var reverse: bool = false:
	set(v):
		reverse = v
		emit_changed()

## --- Abstract Interface ---

## override in subclasses to generate a specific curve shape
func generate_curve(_start: Vector2, _end: Vector2) -> Curve2D:
	push_error("CDCurve.generate_curve() is abstract — override in %s" % get_class())
	return null

## --- Post-Processing ---

## shift all curve points by the offset export
func _apply_offset(curve: Curve2D) -> Curve2D:
	if offset == Vector2.ZERO:
		return curve
	var count := curve.get_point_count()
	var points: PackedVector2Array = PackedVector2Array()
	for i in count:
		points.append(curve.get_point_position(i))
	curve.clear_points()
	for p in points:
		curve.add_point(p + offset)
	return curve

## reverse point order if the reverse export is set
func _reverse_curve(curve: Curve2D) -> Curve2D:
	if not reverse:
		return curve
	var count := curve.get_point_count()
	var points: PackedVector2Array = PackedVector2Array()
	for i in count:
		points.append(curve.get_point_position(count - 1 - i))
	curve.clear_points()
	for p in points:
		curve.add_point(p)
	return curve

## apply offset then reverse — call at end of generate_curve
func _finalize(curve: Curve2D) -> Curve2D:
	return _reverse_curve(_apply_offset(curve))

## --- Reset ---

## override in subclasses that hold mutable state (e.g. CDSequenceCurve)
func reset() -> void:
	pass

## --- Utility ---

## golden-ratio-based phase offset for per-instance variation
func _get_phase() -> float:
	return float(curve_seed) * 0.618 * TAU if curve_seed != 0 else 0.0

## interpolated position along start→end with sin-based depth
func _base_position(start: Vector2, end: Vector2, t: float) -> Vector2:
	var depth := sin(PI * t)
	return Vector2(
		start.x + (end.x - start.x) * depth,
		start.y + (end.y - start.y) * depth,
	)
