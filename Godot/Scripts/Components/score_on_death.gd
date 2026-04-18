extends UniversalComponent

@export var base_score: int = 1
@export var score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS

@onready var health = parent.get_node("Health")

func _ready() -> void:
	health.zero_health.connect(_on_zero_health)

func _on_zero_health(_parent) -> void:
	match score_type:
		CommonEnums.ScoreType.P1_SCORE:
			game.add_p1_score(base_score)
		CommonEnums.ScoreType.P2_SCORE:
			game.add_p2_score(base_score)
		CommonEnums.ScoreType.POINTS:
			game.add_score(base_score)
		CommonEnums.ScoreType.MULTIPLIER:
			game.add_multiplier(base_score)
