extends Node2D

const ASTEROID_SCENE = preload("res://Scenes/Bodies/asteroid.tscn")
const PLAYER_CONTROL_SCENE = preload("res://Scenes/Brains/player_control.tscn")
const ANGLED_DEFLECTOR_SCENE = preload("res://Scenes/Components/angled_deflector.tscn")

const ASTEROID_LAYER: int = 16
const ASTEROID_MASK: int = 22

enum State { ATTRACT, PLAYING, GAME_OVER }

var state: State = State.ATTRACT
var p1_score: int = 0
var p2_score: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 6.0
var max_asteroids: int = 6
var player_ai_ref: Node = null

@onready var ball = $Ball
@onready var opponent_ai = $Opponent/InterceptorAi
@onready var p1_scoreboard = $UI/"P1 Score"
@onready var p2_scoreboard = $UI/"P2 Score"
@onready var goal_sound = $AudioStreamPlayer2D
@onready var attract_text = $UI/"Attract Text"
@onready var p1_win_text = $UI/"Win Text"
@onready var p1_lose_text = $UI/"Lose Text"
@onready var continue_text = $UI/"Continue Text"

func _ready() -> void:
	player_ai_ref = $Player/InterceptorAi
	_randomize_ai(player_ai_ref)
	_randomize_ai(opponent_ai)
	serve_ball()
	_spawn_initial_asteroids()

func _physics_process(delta: float) -> void:
	_monitor_asteroids()
	if state != State.GAME_OVER:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_try_spawn_asteroid()

func _unhandled_input(event: InputEvent) -> void:
	if state == State.ATTRACT:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				_start_game()
	elif state == State.GAME_OVER:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				get_tree().reload_current_scene()
			elif event.keycode == KEY_ESCAPE:
				get_tree().quit()

func _on_ball_collision(collider: Node) -> void:
	if state == State.GAME_OVER:
		return
	if collider.is_in_group("paddles"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)
	elif collider.is_in_group("asteroids"):
		if collider.has_node("AngledDeflector"):
			var physics_angle = collider.get_node("AngledDeflector").bounce_offset(ball.get_global_position())
			ball.custom_bounce(physics_angle)
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)

func _on_asteroid_died(asteroid: Node) -> void:
	asteroid.remove_from_group("asteroids")

func _monitor_asteroids() -> void:
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if asteroid.collision_layer != ASTEROID_LAYER:
			asteroid.collision_layer = ASTEROID_LAYER
			asteroid.collision_mask = ASTEROID_MASK
		var health = asteroid.get_node("Health")
		if not health.zero_health.is_connected(_on_asteroid_died):
			health.zero_health.connect(_on_asteroid_died)
			
			if not asteroid.has_node("AngledDeflector"):
				var deflector = ANGLED_DEFLECTOR_SCENE.instantiate()
				deflector.deflection_bias = Vector2(5, 1)
				asteroid.add_child(deflector)

func _spawn_initial_asteroids() -> void:
	for i in range(4):
		_spawn_single_asteroid()

func _try_spawn_asteroid() -> void:
	var count = get_tree().get_nodes_in_group("asteroids").size()
	if count < max_asteroids:
		_spawn_single_asteroid()

func _spawn_single_asteroid() -> void:
	var asteroid = ASTEROID_SCENE.instantiate()
	asteroid.collision_layer = ASTEROID_LAYER
	asteroid.collision_mask = ASTEROID_MASK

	var spawn_angle = randf() * TAU
	asteroid.global_position = Vector2.from_angle(spawn_angle) * 400 + Vector2(320, 180)

	var speed = randf_range(20.0, 50.0)
	var inward_angle = spawn_angle + PI + randf_range(-0.5, 0.5)
	asteroid.initial_velocity = Vector2.from_angle(inward_angle) * speed

	var deflector = ANGLED_DEFLECTOR_SCENE.instantiate()
	deflector.deflection_bias = Vector2(5, 1)
	asteroid.add_child(deflector)

	add_child(asteroid)

func _randomize_ai(ai: Node) -> void:
	if is_instance_valid(ai):
		ai.turning_speed = randi_range(50, 100)
		ai.aim_inaccuracy = randi_range(10, 30)

func _start_game() -> void:
	state = State.PLAYING
	if is_instance_valid(player_ai_ref):
		player_ai_ref.queue_free()
		player_ai_ref = null
	var pc = PLAYER_CONTROL_SCENE.instantiate()
	$Player.add_child(pc)
	
	opponent_ai.turning_speed = 45
	opponent_ai.aim_inaccuracy = 0
	
	p1_scoreboard.visible = true
	p2_scoreboard.visible = true
	attract_text.visible = false
	
	p1_score = 0
	p2_score = 0
	p1_scoreboard.text = "0"
	p2_scoreboard.text = "0"
	serve_ball()

func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.reset_physics_interpolation()
	ball.velocity = Vector2.ZERO
	ball.reset()

	await get_tree().create_timer(1).timeout

	if not is_inside_tree():
		return

	var angle = randf_range(3 * PI / 4, 5 * PI / 4)
	var direction = randf()
	ball.velocity = Vector2.from_angle(angle)
	if direction > 0.5:
		ball.velocity = ball.velocity * -1
	ball.velocity = ball.velocity * 150

func _on_p_1_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	if state == State.ATTRACT:
		_randomize_ai(player_ai_ref)
		_randomize_ai(opponent_ai)
		serve_ball()
	elif state == State.PLAYING:
		opponent_ai.turning_speed = opponent_ai.turning_speed + 30.0
		p1_score += 1
		p1_scoreboard.text = str(p1_score)
		if p1_score >= 11:
			p1_win()
		else:
			serve_ball()

func _on_p_2_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	if state == State.ATTRACT:
		_randomize_ai(player_ai_ref)
		_randomize_ai(opponent_ai)
		serve_ball()
	elif state == State.PLAYING:
		p2_score += 1
		p2_scoreboard.text = str(p2_score)
		if p2_score >= 11:
			p1_lose()
		else:
			serve_ball()

func p1_win() -> void:
	state = State.GAME_OVER
	ball.velocity = Vector2.ZERO
	p1_win_text.visible = true
	continue_text.visible = true

func p1_lose() -> void:
	state = State.GAME_OVER
	ball.velocity = Vector2.ZERO
	p1_lose_text.visible = true
	continue_text.visible = true
