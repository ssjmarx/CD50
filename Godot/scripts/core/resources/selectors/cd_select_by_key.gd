## CDSelectByKey
## Selects a single entity referenced by a game blackboard key.
## Useful for transitions that need to target a specific entity stored by a director (e.g., SwoopDirector)

class_name CDSelectByKey extends CDSelector

## The blackboard key containing the CDEntity reference
@export var key: StringName = &""

## override — returns the entity from the blackboard if valid and in candidates
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	if not _game or not _game.blackboard.has(key):
		return []
		
	var target = _game.blackboard[key]
	
	# Ensure the target is a valid entity and is actually part of the evaluated candidates
	if is_instance_valid(target) and target is CDEntity and candidates.has(target):
		return [target]
		
	return []
