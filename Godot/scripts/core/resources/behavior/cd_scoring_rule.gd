## cd_scoring_rule.gd
## Produces: a score/multiplier change rule attached to a trigger.
## Consumes: nothing — pure data resource consumed by ScoreManager.
class_name CDScoringRule extends Resource

## The trigger that determines when this rule fires
@export var trigger: CDTrigger

## The flat amount to add to (or subtract from) the score
@export var score_delta: int = 0

## The amount to add to (or subtract from) the multiplier
@export var multiplier_delta: float = 0.0

## Which game bus signal to emit to apply the change
## Expected values: "add_score", "set_score", "add_multiplier", "set_multiplier"
@export var emit_signal: StringName = &"add_score"
