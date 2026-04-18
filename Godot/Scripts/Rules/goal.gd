# marks a parent area2d as a goal and emits scoring signals on body entered

extends UniversalComponent

@export var score_type: CommonEnums.ScoreType
@export var score_amount: int = 1
@export var lose_life: bool = false
@export var extra_life: bool = false

func _ready():
	parent.body_entered.connect(_on_body_entered)

func _on_body_entered(_body):
	match score_type:
		CommonEnums.ScoreType.P1_SCORE:
			game.add_p1_score(score_amount)
		CommonEnums.ScoreType.P2_SCORE:
			game.add_p2_score(score_amount)
		CommonEnums.ScoreType.POINTS:
			game.add_score(score_amount)
		CommonEnums.ScoreType.MULTIPLIER:
			game.add_multiplier(score_amount)
	
	if lose_life:
		game.get_node("LivesCounter").lose_life()

	if extra_life:
		game.get_node("LivesCounter").extra_life()
