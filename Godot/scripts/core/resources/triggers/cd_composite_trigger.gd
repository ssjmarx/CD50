## combines multiple sub-triggers with AND/OR logic
class_name CDCompositeTrigger extends CDTrigger

@export var triggers: Array[CDTrigger] = []
@export var require_all: bool = true

func initialize(game: CDGame) -> void:
	super.initialize(game)
	for trigger in triggers:
		trigger.initialize(game)

func evaluate(delta: float) -> bool:
	if triggers.is_empty():
		return false
	
	if require_all:
		return _evaluate_and(delta)
	else:
		return _evaluate_or(delta)

func consume_pending() -> Array[CDEntity]:
	var all_pending: Array[CDEntity] = []
	for trigger in triggers:
		if trigger is CDSignalTrigger:
			all_pending.append_array(trigger.consume_pending())
	return all_pending

func is_condition_met() -> bool:
	for trigger in triggers:
		if trigger.is_evaluative:
			if not trigger.is_condition_met():
				return false
		else:
			if not trigger.is_condition_met():
				return false
	return true

func reset() -> void:
	for trigger in triggers:
		trigger.reset()
	super.reset()

func _evaluate_and(delta: float) -> bool:
	for trigger in triggers:
		if trigger.is_evaluative:
			if not trigger.is_condition_met():
				return false
	
	for trigger in triggers:
		if not trigger.is_evaluative:
			if not trigger.evaluate(delta):
				return false
	
	return true

func _evaluate_or(delta: float) -> bool:
	for trigger in triggers:
		if trigger.is_evaluative:
			if trigger.is_condition_met():
				return true
	
	for trigger in triggers:
		if not trigger.is_evaluative:
			if trigger.evaluate(delta):
				return true
	
	return false
