# marks a parent area2d as a goal and emits scoring signals on body entered

extends Node

@export var score_type: CommonEnums.ScoreType
@export var score_amount: int = 1

@onready var parent = get_parent()
@onready var game_script = UniversalGameScript.find_ancestor(self)

func _ready():
	parent.body_entered.connect(_on_body_entered)

func _on_body_entered(_body):
	match score_type:
		CommonEnums.ScoreType.P1_SCORE:
			game_script.add_p1_score(score_amount)
		CommonEnums.ScoreType.P2_SCORE:
			game_script.add_p2_score(score_amount)
		CommonEnums.ScoreType.GENERIC_SCORE:
			game_script.add_score(score_amount)
