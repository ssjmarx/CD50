## ScoreManager
## Evaluates an array of CDScoringRule resources against the game state
## Writes pending score/multiplier deltas to the game blackboard and emits apply signals
## Allows complex scoring setups driven entirely by data

class_name ScoreManager extends CDGameComponent

## The scoring rules to evaluate each frame
@export var scoring_rules: Array[CDScoringRule] = []

@export_group("Blackboard Keys")
## key for pending score add delta (int, consumed on trigger)
@export var pending_score_add_key: StringName = &"pending_score_add"
## key for pending score set value (int, consumed on trigger)
@export var pending_score_set_key: StringName = &"pending_score_set"
## key for pending multiplier add delta (float, consumed on trigger)
@export var pending_mult_add_key: StringName = &"pending_mult_add"
## key for pending multiplier set value (float, consumed on trigger)
@export var pending_mult_set_key: StringName = &"pending_mult_set"

## set component category and initialize
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.MANAGER
	super._ready()

## initialize triggers if they require game bus references
func _on_initialize() -> void:
	super._on_initialize()
	for rule in scoring_rules:
		if rule and rule.trigger:
			rule.trigger.initialize(game)

## evaluate all rules and apply deltas if triggers fire
func _physics_process(_delta: float) -> void:
	if not is_inside_tree():
		return
		
	for rule in scoring_rules:
		if rule and rule.trigger and rule.trigger.evaluate(_delta):
			_apply_rule(rule)

## write the rule's deltas to the blackboard and emit the corresponding signal
func _apply_rule(rule: CDScoringRule) -> void:
	match rule.emit_signal:
		&"add_score":
			game.blackboard[pending_score_add_key] = rule.score_delta
			game.bus_emit(&"add_score")
			
		&"set_score":
			game.blackboard[pending_score_set_key] = rule.score_delta
			game.bus_emit(&"set_score")
			
		&"add_multiplier":
			game.blackboard[pending_mult_add_key] = rule.multiplier_delta
			game.bus_emit(&"add_multiplier")
			
		&"set_multiplier":
			game.blackboard[pending_mult_set_key] = rule.multiplier_delta
			game.bus_emit(&"set_multiplier")
