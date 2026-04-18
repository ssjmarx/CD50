extends UniversalComponent

@export var target_group: String
@export var score_amount: int = 1
@export var score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS
@export var listen_signal: String = "body_collided"

func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

func _on_collision(collider: Node, _normal: Vector2) -> void:
	print("scoreonhit collision detected")
	
	if collider.is_in_group(target_group):
		match score_type:
			CommonEnums.ScoreType.P1_SCORE:
				game.add_p1_score(score_amount)
			CommonEnums.ScoreType.P2_SCORE:
				game.add_p2_score(score_amount)
			CommonEnums.ScoreType.POINTS:
				game.add_score(score_amount)
			CommonEnums.ScoreType.MULTIPLIER:
				game.add_multiplier(score_amount)
