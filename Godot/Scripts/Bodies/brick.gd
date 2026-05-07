# Brick Breaker brick with health-based coloring. Color shifts from green to red as HP decreases.

extends UniversalBody

@export var use_score_color: bool = false

var color: Color = Color.WHITE

# Color the brick based on current HP and set the score reward
func _draw() -> void:
	var hp: int = $ScoreOnDeath.base_score
	if use_score_color:
		match hp:
			1, 2: color = Color.YELLOW
			3, 4: color = Color.GREEN
			5, 6: color = Color.ORANGE
			7, _: color = Color.RED
	else:
		color = Color.WHITE
		
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), color)
