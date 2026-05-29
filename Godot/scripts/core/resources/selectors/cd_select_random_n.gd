# CDSelectRandomN
# Selects N random candidates without replacement
# Each evaluation picks independently — different results each time

class_name CDSelectRandomN extends CDSelector

# maximum number of entities to select
@export var count: int = 1

# pick N random candidates from the list (no duplicates)
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	var available: Array[CDEntity] = []
	available.assign(candidates)
	var n: int = mini(count, available.size())

	# pick without replacement by removing from available pool
	var result: Array[CDEntity] = []
	for i in range(n):
		var idx: int = randi_range(0, available.size() - 1)
		result.append(available[idx])
		available.remove_at(idx)
	return result