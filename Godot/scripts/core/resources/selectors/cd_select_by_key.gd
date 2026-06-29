## cd_select_by_key.gd
## Produces: a single-entity selection from a game blackboard key.
## Consumes: game.blackboard[key]; candidate entities.
class_name CDSelectByKey extends CDSelector

## The blackboard key containing the CDEntity reference
@export var key: StringName = &""

## Return the entity stored at the blackboard key, if valid and in candidates.
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	if not _game or not _game.blackboard.has(key):
		return []
		
	var target = _game.blackboard[key]
	
	if is_instance_valid(target) and target is CDEntity and candidates.has(target):
		return [target]
		
	return []