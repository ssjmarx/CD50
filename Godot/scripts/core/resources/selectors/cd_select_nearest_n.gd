## CDSelectNearestN
## Selects N candidates nearest to the closest entity in a target group
## Sorts by distance to reference point, falls back to first-N if no reference

class_name CDSelectNearestN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## group to find the reference point from (nearest entity to first candidate)
@export var target_group: StringName = &"players"

## sort candidates by distance to reference entity, return nearest N
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	if candidates.is_empty():
		return []

	var reference_point: CDEntity = _game.group_registry.get_nearest_to_entity(target_group, candidates[0])

	## fallback: no reference entity found, return first N
	if reference_point == null:
		@warning_ignore("confusable_local_declaration")
		var n: int = mini(count, candidates.size())
		return candidates.slice(0, n)

	## sort candidates by distance to the reference point
	var sorted: Array[CDEntity] = []
	sorted.assign(candidates)
	sorted.sort_custom(func(a: CDEntity, b: CDEntity) -> bool:
		var dist_a = a.global_position.distance_squared_to(reference_point.global_position)
		var dist_b = b.global_position.distance_squared_to(reference_point.global_position)
		return dist_a < dist_b
	)

	var n: int = mini(count, sorted.size())
	return sorted.slice(0, n)
