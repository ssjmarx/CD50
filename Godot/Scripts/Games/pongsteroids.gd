# Pongsteroids: Pong with asteroids as dynamic obstacles. First to 11 wins. Attract mode with AI vs AI.

extends "res://Scripts/Core/universal_game_script.gd"

# Scene preloads
const ASTEROID_SCENE = preload("res://Scenes/Bodies/asteroid.tscn")
const PLAYER_CONTROL_SCENE = preload("res://Scenes/Brains/player_control.tscn")
const ANGLED_DEFLECTOR_SCENE = preload("res://Scenes/Components/angled_deflector.tscn")

# Game state variables
var spawn_timer: float = 0.0 # Timer for asteroid spawning
var spawn_interval: float = 6.0 # Time between spawn attempts
var max_asteroids: int = 6 # Maximum asteroids on screen
var player_ai_ref: Node = null # Reference to attract mode player AI

# Node references
@onready var ball = $Ball
@onready var opponent_ai = $Opponent/InterceptorAi
@onready var goal_sound = $AudioStreamPlayer2D

# Initialize game state and setup
func _ready() -> void:
	super._ready()
	
	# Setup collision groups
	setup_collision_groups({
		"walls": ["balls"],
		"balls": ["walls", "paddles", "asteroids", "goals"],
		"paddles": ["balls"],
		"asteroids": ["balls", "paddles", "asteroids"],
		"goals": ["balls"]
	})
	
	# Get reference to attract mode AI
	player_ai_ref = $Player/InterceptorAi
	
	# Show attract mode UI
	$Interface.show_element(CommonEnums.Element.ATTRACT_TEXT)
	
	# Randomize AI difficulty for variety
	_randomize_ai(player_ai_ref)
	_randomize_ai(opponent_ai)
	
	# Start game
	serve_ball()
	_spawn_initial_asteroids()

# Main physics loop
func _physics_process(delta: float) -> void:
	_monitor_asteroids()
	
	# Spawn asteroids periodically during gameplay
	if current_state != states.GAME_OVER:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_try_spawn_asteroid()

# Handle input events
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	
	# Press Enter to start game from attract mode
	if current_state == states.ATTRACT:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				start_game()

# Handle ball collisions with paddles and asteroids
func _on_ball_collision(collider: Node) -> void:
	if current_state == states.GAME_OVER:
		return
	
	# Paddle collision: accelerate and deflect
	if collider.is_in_group("paddles"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)
	
	# Asteroid collision: deflect and damage
	elif collider.is_in_group("asteroids"):
		if collider.has_node("AngledDeflector"):
			var physics_angle = collider.get_node("AngledDeflector").bounce_offset(ball.get_global_position())
			ball.custom_bounce(physics_angle)
		if collider.has_node("Health"):
			collider.get_node("Health").reduce_health(1)

# Handle asteroid destruction
func _on_asteroid_died(asteroid: Node) -> void:
	asteroid.remove_from_group("asteroids")

# Monitor asteroids and add deflector components if missing
func _monitor_asteroids() -> void:
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		var health = asteroid.get_node("Health")
		
		# Connect death signal if not already connected
		if not health.zero_health.is_connected(_on_asteroid_died):
			health.zero_health.connect(_on_asteroid_died)
			
			# Add angled deflector for ball bounces
			if not asteroid.has_node("AngledDeflector"):
				var deflector = ANGLED_DEFLECTOR_SCENE.instantiate()
				deflector.deflection_bias = Vector2(5, 1)
				asteroid.add_child(deflector)

# Spawn initial set of asteroids
func _spawn_initial_asteroids() -> void:
	for i in range(4):
		_spawn_single_asteroid()

# Try to spawn asteroid if under max count
func _try_spawn_asteroid() -> void:
	var count = get_tree().get_nodes_in_group("asteroids").size()
	if count < max_asteroids:
		_spawn_single_asteroid()

# Spawn a single asteroid at random position
func _spawn_single_asteroid() -> void:
	var asteroid = ASTEROID_SCENE.instantiate()
	
	# Spawn in circle around screen
	var spawn_angle = randf() * TAU
	asteroid.global_position = Vector2.from_angle(spawn_angle) * 400 + Vector2(320, 180)
	
	# Set velocity toward center with some randomness
	var speed = randf_range(20.0, 50.0)
	var inward_angle = spawn_angle + PI + randf_range(-0.5, 0.5)
	asteroid.initial_velocity = Vector2.from_angle(inward_angle) * speed
	
	# Add angled deflector for ball bounces
	var deflector = ANGLED_DEFLECTOR_SCENE.instantiate()
	deflector.deflection_bias = Vector2(5, 1)
	asteroid.add_child(deflector)
	
	add_child(asteroid)

# Randomize AI difficulty for variety
func _randomize_ai(ai: Node) -> void:
	if is_instance_valid(ai):
		ai.turning_speed = randi_range(50, 100)
		ai.aim_inaccuracy = randi_range(10, 30)

# Start playing state
func start_game() -> void:
	super.start_game()
	
	# Update UI
	$Interface.hide_element(CommonEnums.Element.ATTRACT_TEXT)
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
	
	# Clear existing asteroids and spawn fresh ones
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		asteroid.queue_free()
	
	_spawn_initial_asteroids()
	serve_ball()

# Serve ball from center
func serve_ball() -> void:
	ball.position = Vector2(320, 180)
	ball.reset_physics_interpolation()
	ball.velocity = Vector2.ZERO
	ball.reset()
	
	# Wait before serving
	await get_tree().create_timer(1).timeout
	
	if not is_inside_tree():
		return
	
	# Serve at random upward angle, random left/right direction
	var angle = randf_range(3 * PI / 4, 5 * PI / 4)
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
		p1_score += 1
		$Interface.set_p1_score(p1_score)
		
		# Check for win condition
		if p1_score >= 11:
			p1_win()
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
		p2_score += 1
		$Interface.set_p2_score(p2_score)
		
		# Check for win condition
		if p2_score >= 11:
			p1_lose()
		else:
			serve_ball()

# Handle P1 victory
func p1_win() -> void:
	super.p1_win()
	ball.velocity = Vector2.ZERO
	on_game_over.emit(p1_score)

# Handle P1 defeat
func p1_lose() -> void:
	super.p1_lose()
	ball.velocity = Vector2.ZERO
	on_game_over.emit(p2_score)
