# Awards score to the game when the parent collides with a member of the target group.

extends UniversalComponent

# Score configuration
@export var target_group: String
@export var score_amount: float = 1.0
@export var score_type: CommonEnums.ScoreType = CommonEnums.ScoreType.POINTS
@export var listen_signal: String = "body_collided"

# Connect to the specified collision signal
func _ready() -> void:
	parent.connect(listen_signal, _on_collision)

# Award score if the collider is in the target group
func _on_collision(collider: Node, _normal: Vector2) -> void:
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
