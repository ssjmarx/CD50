# reusable user interface.  parent shows/hides pieces as needed, calls update methods on score events

extends Control

var elements = CommonEnums.Element

@onready var parent = get_parent()

func _ready() -> void:
	get_parent().on_points_changed.connect(set_points)
	get_parent().on_multiplier_changed.connect(set_multiplier)

func set_points(new_score) -> void:
	$Points/PointsNumber.text = new_score

func set_multiplier(new_multiplier) -> void:
	$Multiplier/MultiplierNumber.text = new_multiplier

func set_lives(new_lives) -> void:
	$Lives/LivesNumber.text = new_lives

func set_p1_score(new_score) -> void:
	$"P1 Score".text = new_score
	
func set_p2_score(new_score) -> void:
	$"P2 Score".text = new_score

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
