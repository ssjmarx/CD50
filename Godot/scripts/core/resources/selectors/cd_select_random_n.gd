## selects N random candidates. each evaluation picks independently.
class_name CDSelectRandomN extends CDSelector

@export var count: int = 1

func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var available: Array[CDEntity] = []
	available.assign(candidates)
	var n: int = mini(count, available.size())
	var result: Array[CDEntity] = []
	for i in range(n):
		var idx: int = randi_range(0, available.size() - 1)
		result.append(available[idx])
		available.remove_at(idx)
	return result
