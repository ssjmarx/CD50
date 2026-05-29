@tool

## abstract base class for all path curve resources
class_name CDCurve extends Resource

@export var resolution: int = 100:
	set(v):
		resolution = v
		emit_changed()

@export var curve_seed: int = 0:
	set(v):
		curve_seed = v
		emit_changed()

@export var offset: Vector2 = Vector2.ZERO:
	set(v):
		offset = v
		emit_changed()

@export var reverse: bool = false:
	set(v):
		reverse = v
		emit_changed()

## virtual method
func generate_curve(_start: Vector2, _end: Vector2) -> Curve2D:
	push_error("CDCurve.generate_curve() is abstract — override in %s" % get_class())
	return null

## applies the offset to all points in a generated curve
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

## reverses all points in a generated curve
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

## virtual method
func _finalize(curve: Curve2D) -> Curve2D:
	return _reverse_curve(_apply_offset(curve))

## returns a seed-based phase offset
func _get_phase() -> float:
	return float(curve_seed) * 0.618 * TAU if curve_seed != 0 else 0.0

## returns the base round-trip position for a given t
func _base_position(start: Vector2, end: Vector2, t: float) -> Vector2:
	var depth := sin(PI * t)
	return Vector2(
		start.x + (end.x - start.x) * depth,
		start.y + (end.y - start.y) * depth,
	)
