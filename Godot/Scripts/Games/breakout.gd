# Breakout game implementation. Break bricks with ball, lives system, attract mode with AI paddle.

extends "res://Scripts/Core/universal_game_script.gd"

# Scene preloads
const BRICK_SCENE = preload("res://Scenes/Bodies/brick.tscn")
const PLAYER_CONTROL = preload("res://Scenes/Brains/player_control.tscn")

# Game state variables
var using_mouse: bool = false # Track input mode
var paddle_ai_ref: Node = null # Reference to attract mode AI

# Node references
@onready var player = $Paddle
@onready var ball = $Ball
@onready var death_sound = $AudioStreamPlayer2D

# Initialize game state and setup
func _ready() -> void:
	super._ready()
	
	# Connect to node addition to detect new bricks
	get_tree().node_added.connect(_on_node_added)
	
	# Setup collision groups
	setup_collision_groups({
		"walls": ["balls"],
		"balls": ["walls", "paddles", "bricks"],
		"paddles": ["balls"],
		"bricks": ["balls"],
		"floors": ["balls"]
	})
	
	# Connect game signals
	group_cleared.connect(p1_win)
	lives_depleted.connect(p1_lose)
	lives_changed.connect(serve_ball)
	
	# Show attract mode UI
	$Interface.show_element(CommonEnums.Element.ATTRACT_TEXT)
	
	# Start attract mode
	_start_attract_mode()
	
	# Spawn initial bricks and serve ball
	spawn_bricks()
	serve_ball(1)

# Initialize attract mode with AI paddle
func _start_attract_mode() -> void:
	paddle_ai_ref = $Paddle/InterceptorAi
	if not is_instance_valid(paddle_ai_ref):
		var ai = preload("res://Scenes/Brains/interceptor_ai.tscn").instantiate()
		$Paddle.add_child(ai)
		paddle_ai_ref = ai

# Handle input events
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)

# Start playing state
func start_game() -> void:
	super.start_game()
	
	# Remove attract mode AI
	$Paddle/InterceptorAi.queue_free()
	
	# Add player controls
	$Paddle.add_child(PLAYER_CONTROL.instantiate())
	
	# Update UI
	$Interface.hide_element(CommonEnums.Element.ATTRACT_TEXT)
	$Interface.show_element(CommonEnums.Element.LIVES)
	$Interface.show_element(CommonEnums.Element.POINTS)
	$Interface.show_element(CommonEnums.Element.MULTIPLIER)
	
	# Reset game state
	_reset_game()
	$LivesCounter.reset_lives()
	serve_ball($LivesCounter.current_lives)

# Reset game state for new round
func _reset_game() -> void:
	# Clear existing bricks
	for brick in get_tree().get_nodes_in_group("bricks"):
		brick.queue_free()
	await get_tree().process_frame
	
	# Spawn new brick layout
	spawn_bricks()
	
	# Reset score and multiplier
	current_score = 0
	current_multiplier = 1
	on_points_changed.emit(current_score)
	on_multiplier_changed.emit(current_multiplier)
	
	# Reset ball
	ball.velocity = Vector2.ZERO
	ball.accelerator.reset()

# Connect brick death signals when spawned
func _on_node_added(node: Node) -> void:
	if node.is_in_group("bricks") and node.has_node("Health"):
		var health = node.get_node("Health")
		health.zero_health.connect(_on_brick_died)

# Handle ball falling into floor (death zone)
func _on_floor_body_entered(_body) -> void:
	death_sound.play()
	if current_state == states.ATTRACT:
		serve_ball(1)
	elif current_state == states.PLAYING:
		$LivesCounter.lose_life()
		$Interface.set_multiplier(1)

# Spawn brick grid layout
func spawn_bricks() -> void:
	var brick_width = 16
	var brick_height = 8
	var columns = 32
	var rows = 6
	var spacing = 3
	
	# Calculate centered grid
	var total_width = columns * (brick_width + spacing) - spacing
	var start_x = (640 - total_width) / 2.0
	var start_y = 40
	
	# Create brick grid
	for row in range(rows):
		for col in range(columns):
			var brick = BRICK_SCENE.instantiate()
			
			var x = start_x + col * (brick_width + spacing)
			var y = start_y + row * (brick_height + spacing)
			brick.position = Vector2(x, y)
			
			# Top rows have more health
			brick.get_node("Health").max_health = max(5 - row, 1)
			
			add_child(brick)

# Serve ball from paddle position
func serve_ball(lives) -> void:
	if lives < 1:
		return
	
	# Reset ball position and velocity
	ball.position = Vector2(320, 304)
	ball.velocity = Vector2.ZERO
	ball.accelerator.reset()
	
	# Wait before serving
	await get_tree().create_timer(1).timeout
	
	# Serve at upward angle with some randomness
	var angle = randf_range(5 * PI/4, 7 * PI/4)
	ball.velocity = Vector2.from_angle(angle)
	ball.velocity = ball.velocity * 150

# Handle ball collisions
func _on_ball_ball_collision(collider: Node) -> void:
	# Paddle collision: accelerate and deflect based on hit position
	if collider.is_in_group("paddle"):
		ball.accelerate()
		var physics_angle = collider.bounce_offset(ball.get_global_position())
		ball.custom_bounce(physics_angle)
		if current_state == states.PLAYING:
			current_multiplier += 1
			set_multiplier(current_multiplier)
	
	# Brick collision: reduce brick health
	if collider.is_in_group("bricks"):
		var hp = collider.get_node("Health")
		hp.reduce_health(1)

# Handle brick destruction
func _on_brick_died(_brick) -> void:
	if current_state == states.ATTRACT:
		# In attract mode, respawn bricks when all destroyed
		var brick_count = get_tree().get_nodes_in_group("bricks").size()
		if brick_count == 0:
			await get_tree().create_timer(2.0).timeout
			spawn_bricks()
	elif current_state == states.PLAYING:
		# In playing mode, award points
		add_score(current_multiplier)
