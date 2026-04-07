extends Node2D

@onready var ball = $ball
@onready var p1_scoreboard = $"P1 Score"
@onready var p2_scoreboard = $"P2 Score"
@onready var goal_sound = $AudioStreamPlayer2D

var using_mouse: bool = false
var p1_score: int = 0
var p2_score: int = 0

func _ready() -> void:
	serve_ball()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_mouse = true

func _physics_process(_delta: float) -> void:
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
		physics_angle.x = physics_angle.x * 3
		ball.custom_bounce(physics_angle.normalized())

func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.velocity = Vector2.ZERO
	ball.reset()
	
	await get_tree().create_timer(3).timeout	
	
	var angle = randf_range(3 * PI/4, 5 * PI/4)
	var direction = randf()
	ball.velocity = Vector2.from_angle(angle)
	if direction > 0.5:
		ball.velocity = ball.velocity * -1
	ball.velocity = ball.velocity * 150

func _on_p_1_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	p1_score += 1
	p1_scoreboard.text = str(p1_score)
	serve_ball()

func _on_p_2_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	p2_score += 1
	p2_scoreboard.text = str(p2_score)
	serve_ball()
