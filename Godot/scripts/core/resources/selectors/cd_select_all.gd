## CDSelectAll
## Pass-through selector — returns all candidates unchanged
## Use when every entity in a group should participate

class_name CDSelectAll extends CDSelector

## no filtering, return the full candidate list
func select(candidates: Array[CDEntity]) -> Array[CDEntity]:
	return candidates
