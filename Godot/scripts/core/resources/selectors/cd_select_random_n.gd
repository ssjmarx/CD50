## cd_select_random_n.gd
## Produces: N random candidates picked without replacement (fresh each evaluation).
## Consumes: candidate entities only.
class_name CDSelectRandomN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## Pick N random candidates from the list with no duplicates.
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	var available: Array[CDEntity] = []
	available.assign(candidates)
	var n: int = mini(count, available.size())

	var result: Array[CDEntity] = []
	for i in range(n):
		var idx: int = randi_range(0, available.size() - 1)
		result.append(available[idx])
		available.remove_at(idx)
	return result