# Monitors a score value and emits victory or defeat when it meets a condition.
# Connects to the appropriate score signal based on score type.

extends UniversalComponent

# Monitor configuration
@export var score_type: CommonEnums.ScoreType
@export var target_score: int = 11
@export var condition: CommonEnums.Condition
@export var result: CommonEnums.Result

# Connect to the appropriate score signal based on type
func _ready() -> void:
	match score_type:
		CommonEnums.ScoreType.POINTS:
			parent.on_points_changed.connect(_compare)
		CommonEnums.ScoreType.P1_SCORE:
			parent.on_p1_score.connect(_compare)
		CommonEnums.ScoreType.P2_SCORE:
			parent.on_p2_score.connect(_compare)

# Compare current score against target using the configured condition
func _compare(score) -> void:
	match condition:
		CommonEnums.Condition.GREATER_OR_EQUAL:
			if score >= target_score:
				_signal()
		CommonEnums.Condition.LESS_OR_EQUAL:
			if score <= target_score:
				_signal()

# Emit the configured result signal (victory or defeat)
func _signal() -> void:
	match result:
		CommonEnums.Result.DEFEAT:
			parent.defeat.emit()
		CommonEnums.Result.VICTORY:
			parent.victory.emit()
