# Reusable user interface. Parent shows/hides elements and calls update methods on score/lives events.

extends Control

var elements = CommonEnums.Element # Reference to element enums

@onready var parent = get_parent() # Reference to game script

# Connect to game state signals
func _ready() -> void:
	parent.on_points_changed.connect(set_points)
	parent.on_multiplier_changed.connect(set_multiplier)
	parent.lives_changed.connect(set_lives)
	parent.timer_tick.connect(set_timer)

# Update points display
func set_points(new_score) -> void:
	$Points/PointsNumber.text = str(new_score)

# Update multiplier display
func set_multiplier(new_multiplier) -> void:
	$Multiplier/MultiplierNumber.text = str(new_multiplier)

# Update lives display
func set_lives(new_lives) -> void:
	$Lives/LivesNumber.text = str(new_lives)

# Update player 1 score
func set_p1_score(new_score) -> void:
	$"P1 Score".text = str(new_score)
	
# Update player 2 score
func set_p2_score(new_score) -> void:
	$"P2 Score".text = str(new_score)

# Update timer display (TODO: implement)
func set_timer(_new_time) -> void:
	#i'll add this later
	pass

# Show UI element by type
func show_element(element: CommonEnums.Element) -> void:
	match element:
		elements.WIN_TEXT: $"Win Text".visible = true
		elements.LOSE_TEXT: $"Lose Text".visible = true
		elements.CONTINUE_TEXT: $"Continue Text".visible = true
		elements.P1_SCORE: $"P1 Score".visible = true
		elements.P2_SCORE: $"P2 Score".visible = true
		elements.ATTRACT_TEXT: $"Attract Text".visible = true
		elements.LIVES: 
			$Lives.visible = true
			$Lives/LivesNumber.visible = true
		elements.POINTS: 
			$Points.visible = true
			$Points/PointsNumber.visible = true
		elements.MULTIPLIER: 
			$Multiplier.visible = true
			$Multiplier/MultiplierNumber.visible = true
		elements.CONTROL_TEXT: $"Attract Text/ControlText".visible = true

# Hide UI element by type
func hide_element(target_element: CommonEnums.Element) -> void:
	match target_element:
		elements.WIN_TEXT: $"Win Text".visible = false
		elements.LOSE_TEXT: $"Lose Text".visible = false
		elements.CONTINUE_TEXT: $"Continue Text".visible = false
		elements.P1_SCORE: $"P1 Score".visible = false
		elements.P2_SCORE: $"P2 Score".visible = false
		elements.ATTRACT_TEXT: $"Attract Text".visible = false
		elements.LIVES:
			$Lives.visible = false
			$Lives/LivesNumber.visible = false
		elements.POINTS: 
			$Points.visible = false
			$Points/PointsNumber.visible = false
		elements.MULTIPLIER: 
			$Multiplier.visible = false
			$Multiplier/MultiplierNumber.visible = false
		elements.CONTROL_TEXT: $"Attract Text/ControlText".visible = false
