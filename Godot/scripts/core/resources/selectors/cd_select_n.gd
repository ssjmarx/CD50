## CDSelectN
## Selects the first N candidates in iteration order
## Simple and deterministic — no sorting or randomization

class_name CDSelectN extends CDSelector

## maximum number of entities to select
@export var count: int = 1

## return the first N candidates (or fewer if not enough exist)
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var n: int = mini(count, candidates.size())
	return candidates.slice(0, n)
