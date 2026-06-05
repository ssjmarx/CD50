## StageManager
## Evaluates CDStageRule triggers each frame and sleeps/wakes named CDStages
## Replaces the sleep_on/wake_on arrays that were embedded in CDStage

class_name StageManager extends CDGameComponent

## --- Exports ---

## rules defining when to sleep/wake stages and what signals to emit
@export var rules: Array[CDStageRule] = []

## --- State ---

## cached lookup: stage node name → CDStage reference
var _stage_map: Dictionary = {}

## --- Lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.MANAGER
	super._ready()

func _on_initialize() -> void:
	_build_stage_map()
	for rule in rules:
		if rule.is_valid():
			rule.initialize(game)
		else:
			push_warning("StageManager '%s': skipping invalid rule." % name)

## --- Setup ---

## find all sibling CDStages and build name → reference map
func _build_stage_map() -> void:
	_stage_map.clear()
	var found = game.find_children("*", "CDStage")
	for node in found:
		if node is CDStage:
			_stage_map[node.name] = node

## --- Processing ---

## evaluate all rule triggers each frame
func _physics_process(delta: float) -> void:
	for rule in rules:
		if not rule.is_valid():
			continue
		if rule.trigger and rule.trigger.evaluate(delta):
			_execute_rule(rule)

## --- Execution ---

## sleep/wake stages and emit signals for a matching rule
func _execute_rule(rule: CDStageRule) -> void:
	for stage_name in rule.sleep_stages:
		var stage: CDStage = _stage_map.get(stage_name)
		if stage:
			stage.sleep()

	for stage_name in rule.wake_stages:
		var stage: CDStage = _stage_map.get(stage_name)
		if stage:
			stage.wake()

	for sig in rule.game_signals:
		if sig != &"":
			game.bus_emit(sig)

## --- Reset ---

## reset all rules for game restart
func reset() -> void:
	for rule in rules:
		rule.reset()