# Reusable user interface. Parent shows/hides elements and calls update methods on score/lives events.

extends Control

@export var display_mode: CommonEnums.DisplayMode = CommonEnums.DisplayMode.P1_P2_SCORE
@export var display_lives: bool = false
@export var animate_score: bool = true
@export var score_animation_duration: float = 0.3

var elements = CommonEnums.Element

var _displayed_points: int = 0
var _displayed_p1: int = 0
var _displayed_p2: int = 0

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

# Update points display (with optional tick-up animation)
func set_points(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_points != target:
		_animate_score("_displayed_points", target, $Points/PointsNumber, "_points_tween")
	else:
		_displayed_points = target
		$Points/PointsNumber.text = str(target)

# Update multiplier display
func set_multiplier(new_multiplier) -> void:
	$Multiplier/MultiplierNumber.text = str(int(new_multiplier)) + "x"

# Update lives display
func set_lives(new_lives) -> void:
	$Lives/LivesNumber.text = str(int(new_lives))

# Update player 1 score (with optional tick-up animation)
func set_p1_score(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_p1 != target:
		_animate_score("_displayed_p1", target, $"P1 Score", "_p1_tween")
	else:
		_displayed_p1 = target
		$"P1 Score".text = str(target)

# Update player 2 score (with optional tick-up animation)
func set_p2_score(new_score) -> void:
	var target = int(new_score)
	if animate_score and _displayed_p2 != target:
		_animate_score("_displayed_p2", target, $"P2 Score", "_p2_tween")
	else:
		_displayed_p2 = target
		$"P2 Score".text = str(target)

# Animate a score value ticking up from current to target
func _animate_score(prop: String, target: int, label: Node, tween_prop: String) -> void:
	# Kill any existing tween for this score
	var old_tween: Tween = get(tween_prop)
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	
	var current: int = get(prop)
	var new_tween = create_tween()
	new_tween.tween_method(func(val): label.text = str(int(val)), float(current), float(target), score_animation_duration)
	set(tween_prop, new_tween)
	set(prop, target)

# Update timer display — TODO: implement
func set_timer(_new_time) -> void:
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
