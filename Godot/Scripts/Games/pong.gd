extends "res://Scripts/Core/universal_game_script.gd"

var using_mouse: bool = false
var p1_score: int = 0
var p2_score: int = 0
var player_ai_ref: Node = null

@onready var ball = $Ball
@onready var goal_sound = $AudioStreamPlayer2D
@onready var opponent_ai = $Opponent/InterceptorAi

func _ready() -> void:
	super._ready()
	
	setup_collision_groups({
	"walls": ["balls"],
	"balls": ["walls", "paddles", "goals"],
	"paddles": ["balls"],
	"goals": ["balls"]
	})
	
	player_ai_ref = $Player/InterceptorAi
	
	_randomize_ai(player_ai_ref)
	_randomize_ai(opponent_ai)
	
	serve_ball()

func _randomize_ai(ai: Node) -> void:
	if is_instance_valid(ai):
		ai.turning_speed = randi_range(50, 100)
		ai.aim_inaccuracy = randi_range(10, 30)

func _unhandled_input(event: InputEvent) -> void:	
	if game_over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _on_ball_collision(collider: Node) -> void:
	if collider.is_in_group("paddles"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)

func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.reset_physics_interpolation()
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
	opponent_ai.turning_speed = opponent_ai.turning_speed + 30.0
	p1_score += 1
	#p1_scoreboard.text = str(p1_score)
	if p1_score >= 11:
		p1_win()
	else:
		serve_ball()

func _on_p_2_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	p2_score += 1
	#p2_scoreboard.text = str(p2_score)
	if p2_score >= 11:
		p1_lose()
	else:
		serve_ball()

func p1_win() -> void:
	current_state = states.GAME_OVER
	#p1_win_text.visible = true
	#continue_text.visible = true

func p1_lose() -> void:
	current_state = states.GAME_OVER
	#p1_lose_text.visible = true
	#continue_text.visible = true
