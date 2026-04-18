extends UniversalComponent

@export var score_type: CommonEnums.ScoreType
@export var target_score: int = 11
@export var condition: CommonEnums.Condition
@export var result: CommonEnums.Result

func _ready() -> void:
	match score_type:
		CommonEnums.ScoreType.POINTS:
			parent.on_points_changed.connect(_compare)
		CommonEnums.ScoreType.P1_SCORE:
			parent.on_p1_score.connect(_compare)
		CommonEnums.ScoreType.P2_SCORE:
			parent.on_p2_score.connect(_compare)

func _compare(score) -> void:
	match condition:
		CommonEnums.Condition.GREATER_OR_EQUAL:
			if score >= target_score:
				_signal()
		CommonEnums.Condition.LESS_OR_EQUAL:
			if score <= target_score:
				_signal()

func _signal() -> void:
	match result:
		CommonEnums.Result.DEFEAT:
			parent.defeat.emit()
		CommonEnums.Result.VICTORY:
			parent.victory.emit()
