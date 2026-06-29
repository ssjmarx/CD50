## CDSelectNearestN
## Selects N candidates nearest to the caller's (e.g. StateManager's) position
## Sorts by distance to source_position, returns the closest N

class_name CDSelectNearestN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## sort candidates by distance to source_position, return nearest N
func select(candidates: Array[CDEntity], source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	if candidates.is_empty():
		return []

	## sort candidates by distance to the director's position
	var sorted: Array[CDEntity] = []
	sorted.assign(candidates)
	sorted.sort_custom(func(a: CDEntity, b: CDEntity) -> bool:
		return a.global_position.distance_squared_to(source_position) < \
			b.global_position.distance_squared_to(source_position)
	)

	var n: int = mini(count, sorted.size())
	return sorted.slice(0, n)