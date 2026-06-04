## CDSelectSignalEmitter
## Filters candidates to only those who emitted a specific signal this frame
## Cross-references the emitter registry on game or entity bus

class_name CDSelectSignalEmitter extends CDSelector

## signal name to check in the emitter registry
@export var signal_name: StringName = &""

## which bus to check: true = game bus, false = entity bus
@export var use_game_bus: bool = true

## filter candidates to only those present in the emitter registry for this signal
func select(candidates: Array[CDEntity], _source_position: Vector2 = Vector2.ZERO) -> Array[CDEntity]:
	if signal_name == &"" or _game == null:
		return candidates

	if use_game_bus:
		var emitters: Array = _game._signal_emitters.get(signal_name, [])
		var result: Array[CDEntity] = []
		for entity in candidates:
			if entity in emitters:
				result.append(entity)
		return result
	else:
		## entity bus: check each candidate's own emitter registry
		var result: Array[CDEntity] = []
		for entity in candidates:
			var entity_emitters: Array = entity._signal_emitters.get(signal_name, [])
			if entity in entity_emitters:
				result.append(entity)
		return result