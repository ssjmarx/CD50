# Reusable user interface. Parent shows/hides elements and calls update methods on score/lives events.

extends Control

@export var display_mode: CommonEnums.DisplayMode = CommonEnums.DisplayMode.P1_P2_SCORE
@export var display_lives: bool = false

var elements = CommonEnums.Element

@onready var parent = get_parent()

# Connect to game state signals
func _ready() -> void:
	parent.on_points_changed.connect(set_points)
	parent.on_multiplier_changed.connect(set_multiplier)
	parent.lives_changed.connect(set_lives)
	parent.timer_tick.connect(set_timer)
	parent.on_p1_score.connect(set_p1_score)
	parent.on_p2_score.connect(set_p2_score)
	parent.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: CommonEnums.State) -> void:
	match new_state:
		CommonEnums.State.ATTRACT:
			_hide_play_ui()
			show_element(elements.ATTRACT_TEXT)
		CommonEnums.State.PLAYING:
			hide_element(elements.ATTRACT_TEXT)
			_show_play_ui()
		CommonEnums.State.GAME_OVER:
			hide_element(elements.ATTRACT_TEXT)
			_hide_play_ui()

func _show_play_ui() -> void:
	match display_mode:
		CommonEnums.DisplayMode.P1_P2_SCORE:
			show_element(elements.P1_SCORE)
			show_element(elements.P2_SCORE)
		CommonEnums.DisplayMode.POINTS_MULTIPLIER:
			show_element(elements.POINTS)
			show_element(elements.MULTIPLIER)
	
	if display_lives:
		show_element(elements.LIVES)

func _hide_play_ui() -> void:
	hide_element(elements.P1_SCORE)
	hide_element(elements.P2_SCORE)
	hide_element(elements.POINTS)
	hide_element(elements.MULTIPLIER)
	hide_element(elements.LIVES)

# Update points display
func set_points(new_score) -> void:
	$Points/PointsNumber.text = str(int(new_score))

# Update multiplier display
func set_multiplier(new_multiplier) -> void:
	$Multiplier/MultiplierNumber.text = str(int(new_multiplier)) + "x"

# Update lives display
func set_lives(new_lives) -> void:
	$Lives/LivesNumber.text = str(int(new_lives))

# Update player 1 score
func set_p1_score(new_score) -> void:
	$"P1 Score".text = str(int(new_score))
	
# Update player 2 score
func set_p2_score(new_score) -> void:
	$"P2 Score".text = str(int(new_score))

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
