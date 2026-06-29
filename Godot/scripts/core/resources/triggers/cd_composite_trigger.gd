## cd_composite_trigger.gd
## Produces: a composite trigger combining child triggers with AND/OR logic.
## Consumes: child CDTrigger resources (evaluative checked first, then events).
class_name CDCompositeTrigger extends CDTrigger

## sub-triggers to evaluate as a group
@export var triggers: Array[CDTrigger] = []

## true = all must be met (AND), false = any can be met (OR)
@export var require_all: bool = true

## Initialize all sub-triggers with the game reference.
func initialize(game: CDGame) -> void:
	super.initialize(game)
	for trigger in triggers:
		trigger.initialize(game)

## Dispatch to AND or OR evaluation based on require_all.
func evaluate(delta: float) -> bool:
	if triggers.is_empty():
		return false

	if require_all:
		return _evaluate_and(delta)
	else:
		return _evaluate_or(delta)

## Return true if every sub-trigger's condition is currently met.
func is_condition_met() -> bool:
	for trigger in triggers:
		if trigger.is_evaluative:
			if not trigger.is_condition_met():
				return false
		else:
			if not trigger.is_condition_met():
				return false
	return true

## Reset all sub-triggers then self.
func reset() -> void:
	for trigger in triggers:
		trigger.reset()
	super.reset()

## AND: all evaluative conditions must be met AND all event triggers must fire.
func _evaluate_and(delta: float) -> bool:
	## check all evaluative conditions first (cheap)
	for trigger in triggers:
		if trigger.is_evaluative:
			if not trigger.is_condition_met():
				return false

	## then check all event triggers (may consume events)
	for trigger in triggers:
		if not trigger.is_evaluative:
			if not trigger.evaluate(delta):
				return false

	return true

## OR: any evaluative condition met OR any event trigger fires.
func _evaluate_or(delta: float) -> bool:
	## check all evaluative conditions first
	for trigger in triggers:
		if trigger.is_evaluative:
			if trigger.is_condition_met():
				return true

	## then check all event triggers
	for trigger in triggers:
		if not trigger.is_evaluative:
			if trigger.evaluate(delta):
				return true

	return false