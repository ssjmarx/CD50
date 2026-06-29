## cd_select_nearest_n.gd
## Produces: the N candidates nearest to the caller's source_position.
## Consumes: candidate entities; source_position (e.g. director's global_position).
class_name CDSelectNearestN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## Sort candidates by distance to source_position and return the nearest N.
func select(candidates: Array[CDEntity], source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	if candidates.is_empty():
		return []

	var sorted: Array[CDEntity] = []
	sorted.assign(candidates)
	sorted.sort_custom(func(a: CDEntity, b: CDEntity) -> bool:
		return a.global_position.distance_squared_to(source_position) < \
			b.global_position.distance_squared_to(source_position)
	)

	var n: int = mini(count, sorted.size())
	return sorted.slice(0, n)