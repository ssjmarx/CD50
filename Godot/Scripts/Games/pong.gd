# Pong game implementation. Two-player competitive, first to 11 wins. Attract mode with AI vs AI.

extends "res://Scripts/Core/universal_game_script.gd"

# Scene preloads
const PLAYER_CONTROL_SCENE = preload("res://Scenes/Brains/player_control.tscn")

# Game state variables
var using_mouse: bool = false # Track input mode
var p1_score: int = 0 # Player 1 score (left paddle)
var p2_score: int = 0 # Player 2 score (right paddle)
var player_ai_ref: Node = null # Reference to attract mode player AI

# Node references
@onready var ball = $Ball
@onready var goal_sound = $AudioStreamPlayer2D
@onready var opponent_ai = $Opponent/InterceptorAi

# Initialize game state and setup
func _ready() -> void:
	super._ready()
	
	# Setup collision groups
	setup_collision_groups({
		"walls": ["balls"],
		"balls": ["walls", "paddles", "goals"],
		"paddles": ["balls"],
		"goals": ["balls"]
	})
	
	# Get reference to attract mode AI
	player_ai_ref = $Player/InterceptorAi
	
	# Show attract mode UI
	$Interface.show_element(CommonEnums.Element.ATTRACT_TEXT)
	
	# Start attract mode
	_start_attract_mode()
	
	# Serve initial ball
	serve_ball()

# Randomize AI difficulty for variety
func _randomize_ai(ai: Node) -> void:
	if is_instance_valid(ai):
		ai.turning_speed = randi_range(50, 100)
		ai.aim_inaccuracy = randi_range(10, 30)

# Initialize attract mode with randomized AI
func _start_attract_mode() -> void:
	_randomize_ai(player_ai_ref)
	_randomize_ai(opponent_ai)

# Start playing state
func start_game() -> void:
	super.start_game()
	
	# Update UI
	$Interface.hide_element(CommonEnums.Element.ATTRACT_TEXT)
	$Interface.hide_element(CommonEnums.Element.CONTINUE_TEXT)
	$Interface.show_element(CommonEnums.Element.P1_SCORE)
	$Interface.show_element(CommonEnums.Element.P2_SCORE)
	
	# Remove attract mode AI and add player controls
	if is_instance_valid(player_ai_ref):
		player_ai_ref.queue_free()
		player_ai_ref = null
	var pc = PLAYER_CONTROL_SCENE.instantiate()
	$Player.add_child(pc)
	
	# Set opponent AI to standard difficulty
	opponent_ai.turning_speed = 45
	opponent_ai.aim_inaccuracy = 0
	
	# Reset scores
	p1_score = 0
	p2_score = 0
	$Interface.set_p1_score(p1_score)
	$Interface.set_p2_score(p2_score)
	
	serve_ball()

# Handle input events
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	
	# Press Enter to start game from attract mode
	if current_state == states.ATTRACT:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				start_game()

# Handle ball collisions
func _on_ball_collision(collider: Node) -> void:
	# Paddle collision: accelerate and deflect
	if collider.is_in_group("paddles"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)

# Serve ball from center
func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.reset_physics_interpolation()
	ball.velocity = Vector2.ZERO
	ball.reset()
	
	# Wait before serving
	await get_tree().create_timer(1).timeout
	
	# Serve at random upward angle, random left/right direction
	var angle = randf_range(3 * PI/4, 5 * PI/4)
	var direction = randf()
	ball.velocity = Vector2.from_angle(angle)
	if direction > 0.5:
		ball.velocity = ball.velocity * -1
	ball.velocity = ball.velocity * 150

# Handle P1 goal (ball enters right side) - P2 scores
func _on_p_1_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	if current_state == states.ATTRACT:
		# Randomize AI for variety in attract mode
		_randomize_ai(player_ai_ref)
		_randomize_ai(opponent_ai)
		serve_ball()
	elif current_state == states.PLAYING:
		# Increase opponent difficulty slightly
		opponent_ai.turning_speed = opponent_ai.turning_speed + 30.0
		p2_score += 1
		$Interface.set_p2_score(p2_score)
		
		# Check for win condition
		if p2_score >= 11:
			p1_lose()
		else:
			serve_ball()

# Handle P2 goal (ball enters left side) - P1 scores
func _on_p_2_goal_body_entered(_body: Node2D) -> void:
	goal_sound.play()
	if current_state == states.ATTRACT:
		# Randomize AI for variety in attract mode
		_randomize_ai(player_ai_ref)
		_randomize_ai(opponent_ai)
		serve_ball()
	elif current_state == states.PLAYING:
		p1_score += 1
		$Interface.set_p1_score(p1_score)
		
		# Check for win condition
		if p1_score >= 11:
			p1_win()
		else:
			serve_ball()

# Handle P1 victory
func p1_win() -> void:
	super.p1_win()
	on_game_over.emit(p1_score)

# Handle P1 defeat
func p1_lose() -> void:
	super.p1_lose()
	on_game_over.emit(p2_score)
