## selects the first N candidates in iteration order.
class_name CDSelectN extends CDSelector

@export var count: int = 1

func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var n: int = mini(count, candidates.size())
	return candidates.slice(0, n)
