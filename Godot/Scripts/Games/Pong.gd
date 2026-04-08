extends Node2D

@onready var ball = $ball
@onready var p1_scoreboard = $"P1 Score"
@onready var p2_scoreboard = $"P2 Score"
@onready var goal_sound = $AudioStreamPlayer2D
@onready var opponent_ai = $opponent/InterceptorAi
@onready var p1_win_text = $"Win Text"
@onready var p1_lose_text = $"Lose Text"
@onready var continue_text = $"Continue Text"

var using_mouse: bool = false
var p1_score: int = 0
var p2_score: int = 0
var game_over: bool = false

func _ready() -> void:
	serve_ball()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_mouse = true
	
	if game_over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _physics_process(_delta: float) -> void:
	if game_over:
		return
	
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	
	if direction != Vector2.ZERO:
		using_mouse = false
		$player.set_direct_movement(direction)
	elif using_mouse:
		var mouse_pos = get_global_mouse_position()
		$player.set_target_coords(mouse_pos)
	else:
		$player.set_direct_movement(Vector2.ZERO)

func _on_ball_collision(collider: Node) -> void:
	if collider.is_in_group("paddles"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		physics_angle.x = physics_angle.x * 5
		ball.custom_bounce(physics_angle.normalized())

func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.velocity = Vector2.ZERO
	ball.reset()
	
	await get_tree().create_timer(1).timeout
	
	var angle = randf_range(3 * PI/4, 5 * PI/4)
	var direction = randf()
	ball.velocity = Vector2.from_angle(angle)
	if direction > 0.5:
		ball.velocity = ball.velocity * -1
	ball.velocity = ball.velocity * 150

func _on_p_1_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	opponent_ai.turning_speed = minf(opponent_ai.turning_speed + 10.0, 100.0)
	p1_score += 1
	p1_scoreboard.text = str(p1_score)
	if p1_score >= 11:
		p1_win()
	else:
		serve_ball()

func _on_p_2_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	p2_score += 1
	p2_scoreboard.text = str(p2_score)
	if p2_score >= 11:
		p1_lose()
	else:
		serve_ball()

func p1_win() -> void:
	game_over = true
	p1_win_text.visible = true
	continue_text.visible = true

func p1_lose() -> void:
	game_over = true
	p1_lose_text.visible = true
	continue_text.visible = true
