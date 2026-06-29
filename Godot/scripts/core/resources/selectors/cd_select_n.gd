## cd_select_n.gd
## Produces: the first N candidates in iteration order (deterministic, no sorting).
## Consumes: candidate entities only.
class_name CDSelectN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## Return the first N candidates (or fewer if not enough exist).
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	var n: int = mini(count, candidates.size())
	return candidates.slice(0, n)
