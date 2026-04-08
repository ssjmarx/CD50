extends Node2D

@onready var player = $paddle
@onready var ball = $ball
@onready var lives_display = $UI/lives/livesnumber
@onready var p1_win_text = $UI/"Win Text"
@onready var p1_lose_text = $UI/"Lose Text"
@onready var continue_text = $UI/"Continue Text"
@onready var points_number = $UI/points/pointsnumber
@onready var multiplier_number = $UI/multiplier/multipliernumber
@onready var death_sound = $AudioStreamPlayer2D

const BRICK_SCENE = preload("res://Scenes/Components/brick.tscn")

var using_mouse: bool = false
var game_over = false
var lives = 3
var brick_count = 0
var multiplier = 1
var points = 0

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _ready() -> void:
	spawn_bricks()
	serve_ball()

func _on_floor_body_entered(body: Node2D) -> void:
	if body == ball:
		death_sound.play()
		if lives > 0:
			lives -= 1
			lives_display.text = str(lives)
			multiplier = 1
			multiplier_number.text = str(multiplier) + "x"
			serve_ball()
		else:
			p1_lose()

func spawn_bricks() -> void:
	var brick_width = 16
	var brick_height = 8
	var columns = 32
	var rows = 6
	var spacing = 3
	
	var total_width = columns * (brick_width + spacing) - spacing
	var start_x = (640 - total_width) / 2.0
	var start_y = 40
	
	for row in range(rows):
		for col in range(columns):
			var brick = BRICK_SCENE.instantiate()
			
			var x = start_x + col * (brick_width + spacing)
			var y = start_y + row * (brick_height + spacing)
			brick.position = Vector2(x, y)
			
			brick.add_to_group("bricks")
			
			brick.get_node("health").max_health = max(5 - row, 1)
			
			add_child(brick)
			brick_count += 1

func serve_ball() -> void:
	ball.position = Vector2(320, 304)
	ball.velocity = Vector2.ZERO
	ball.accelerator.reset()
	
	await get_tree().create_timer(1).timeout
	
	var angle = randf_range(5 * PI/4, 7 * PI/4)
	ball.velocity = Vector2.from_angle(angle)
	ball.velocity = ball.velocity * 150

func p1_win() -> void:
	game_over = true
	p1_win_text.visible = true
	continue_text.visible = true
	ball.velocity = Vector2.ZERO

func p1_lose() -> void:
	game_over = true
	p1_lose_text.visible = true
	continue_text.visible = true

func _on_ball_ball_collision(collider: Node) -> void:
	if collider.is_in_group("paddle"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)
		multiplier = 1
		multiplier_number.text = str(multiplier) + "x"
		
	if collider.is_in_group("bricks"):
		var hp = collider.get_node("health")
		hp.reduce_health(1)
		if hp.current_health <= 0:
			brick_count -= 1
		if brick_count <= 0:
			p1_win()
		points += 1 * multiplier
		points_number.text = str(points)
		multiplier += 1
		multiplier_number.text = str(multiplier) + "x"
