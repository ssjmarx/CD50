# Goal zone that awards score, causes life loss, or grants extra lives when a body enters.
# Attaches to an Area2D parent and listens for body_entered.

extends UniversalComponent

# Scoring and life configuration
@export var score_type: CommonEnums.ScoreType
@export var score_amount: int = 1
@export var lose_life: bool = false
@export var extra_life: bool = false

# Connect to parent Area2D's body_entered signal
func _ready() -> void:
	parent.body_entered.connect(_on_body_entered)

# Award score and apply life effects when a body enters the goal zone
func _on_body_entered(_body: Node) -> void:
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
