## cd_select_all.gd
## Produces: all candidates unchanged (pass-through selector).
## Consumes: candidate entities only.
class_name CDSelectAll extends CDSelector

## Return the full candidate list with no filtering.
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	return candidates
