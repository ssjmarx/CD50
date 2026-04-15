# Asteroids game implementation. Supports two control schemes (Original/Modern) and attract mode.

extends "res://Scripts/Core/universal_game_script.gd"

# Scene preloads
const SHIP_SCENE = preload("res://Scenes/Bodies/triangle_ship.tscn")
const ASTEROID_SCENE = preload("res://Scenes/Bodies/asteroid.tscn")
const SCREEN_WRAP = preload("res://Scenes/Components/screen_wrap.tscn")
const GUN = preload("res://Scenes/Arms/gun_simple.tscn")
const BULLET = preload("res://Scenes/Bodies/bullet_simple.tscn")
const PLAYER_CONTROLS = preload("res://Scenes/Brains/player_control.tscn")
const ATTRACT_ROTATION = preload("res://Scenes/Legs/rotation_target.tscn")
const ATTRACT_AI = preload("res://Scenes/Brains/aim_ai.tscn")

# Game constants
const SPAWN_RADIUS = 320.0 # Distance from center to spawn asteroids
const SCREEN_CENTER = Vector2(320, 180) # Center of game screen
const SAFE_ZONE_RADIUS = 100.0 # Radius around center where ship can safely spawn
const RESPAWN_DELAY = 3.0 # Seconds before ship respawns after death
const WAVE_BASE_COUNT = 4 # Base number of asteroids per wave

# Game state variables
var current_wave: int = 0 # Current wave number
var control_setting: Controls # Active control scheme
var attract_mode_timer: float = 0.0 # Timer for attract mode shooting
var shoot_interval: float = 1.0 # Time between attract mode shots
var player_spawning = false # Prevents duplicate ship spawns
var attract_respawn_timer: float = 0.0 # Timer for attract mode ship respawn
var _spawning_attract_ship := false # Prevents duplicate attract ship spawns

# Control scheme enum
enum Controls {
	ORIGINAL, # Classic Asteroids: rotation_direct + engine_simple
	MODERN # Modern: rotation_target + engine_complex + direct_acceleration + friction_linear
}

# Component configurations for each control scheme
var control_configs = {
	Controls.ORIGINAL: [
		"res://Scenes/Legs/rotation_direct.tscn",
        "res://Scenes/Legs/engine_simple.tscn"
	],
	Controls.MODERN: [
		"res://Scenes/Legs/rotation_target.tscn",
		"res://Scenes/Legs/engine_complex.tscn",
		"res://Scenes/Legs/direct_acceleration.tscn",
        "res://Scenes/Legs/friction_linear.tscn"
	]
}

# Node references
@onready var player_ship = $Player
@onready var gun = $Player/GunSimple
@onready var ai_brain = $Player/AimAi
@onready var ai_leg = $Player/RotationTarget

# Initialize game state and setup
func _ready() -> void:
	super._ready()
	
	# Connect to node addition to detect new asteroids
	get_tree().node_added.connect(_on_node_added)
	
	# Show attract mode UI
	$Interface.show_element(CommonEnums.Element.ATTRACT_TEXT)
	$Interface.show_element(CommonEnums.Element.CONTROL_TEXT)
	
	# Setup collision groups
	setup_collision_groups({
		"asteroids": ["asteroids", "ships"],
		"ships": ["asteroids", "bullets"],
		"bullets": ["ships", "asteroids"],
	})
	
	# Connect game signals
	gun.target_hit.connect(_on_bullet_hit)
	group_cleared.connect(_on_group_cleared)
	lives_depleted.connect(p1_lose)
	lives_changed.connect(_on_lives_changed)
	
	# Start game
	_spawn_wave()
	_start_attract_mode()

# Handle player lives change
func _on_lives_changed(current_lives):
	_respawn_ship(current_lives, RESPAWN_DELAY)

# Handle key input for control scheme selection
func _unhandled_input(event: InputEvent) -> void:
	if current_state == states.ATTRACT:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_1:
				_transition_to_playing(Controls.ORIGINAL)
				return
			elif event.keycode == KEY_2:
				_transition_to_playing(Controls.MODERN)
				return
	super._unhandled_input(event)

# Initialize attract mode state
func _start_attract_mode() -> void:
	attract_mode_timer = 0.0
	attract_respawn_timer = 0.0
	shoot_interval = 1.0
	if not has_node("Player"):
		_spawn_attract_ship()

# Clean up attract mode references
func _stop_attract_mode() -> void:
	attract_mode_timer = 0.0
	attract_respawn_timer = 0.0
	
	# Clear attract mode references
	ai_brain = null
	ai_leg = null
	_spawning_attract_ship = false

# Update attract mode behavior (AI plays the game)
func _update_attract_mode(delta: float) -> void:
	if has_node("Player") and is_instance_valid(player_ship):
		var asteroids = get_tree().get_nodes_in_group("asteroids")
		
		# AI aims at nearest asteroid
		if asteroids.size() > 0 and is_instance_valid(ai_brain):
			var nearest_asteroid = null
			var nearest_distance = INF
			
			for asteroid in asteroids:
				var distance = player_ship.global_position.distance_to(asteroid.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_asteroid = asteroid
			
			if nearest_asteroid:
				ai_brain.set_target_node(nearest_asteroid)
		
		# Only shoot if there are asteroids to shoot at
		if asteroids.size() > 0:
			attract_mode_timer += delta
			if attract_mode_timer >= shoot_interval:
				attract_mode_timer = 0.0
				shoot_interval = randf_range(0.3, 1.5)
				
				player_ship.shoot.emit()
	else:
		# Clear invalid references when ship is gone
		if not is_instance_valid(player_ship):
			player_ship = null
			ai_brain = null
			ai_leg = null
		
		# Only spawn if not already spawning
		if not _spawning_attract_ship:
			attract_respawn_timer += delta
			if attract_respawn_timer >= RESPAWN_DELAY:
				attract_respawn_timer = 0.0
				_spawning_attract_ship = true
				_spawn_attract_ship()

# Main physics loop
func _physics_process(delta: float) -> void:
	# Update attract mode if active
	if current_state == states.ATTRACT:
		_update_attract_mode(delta)
	
	# Update multiplier based on asteroid count
	var current_asteroid_count = get_tree().get_nodes_in_group("asteroids").size()
	set_multiplier(current_asteroid_count)

# Handle group cleared (all asteroids destroyed)
func _on_group_cleared(group_name: String) -> void:
	if group_name == "asteroids":
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		_spawn_wave()

# Handle bullet hit on target
func _on_bullet_hit(target: Node) -> void:
	if target.has_node("Health"):
		target.set_meta("killed_by_bullet", true)
		target.get_node("Health").reduce_health(1)

# Load control components based on selected scheme
func _load_controls(setting: Controls):
	# Remove existing control components
	if is_instance_valid(ai_brain):
		ai_brain.queue_free()
	if is_instance_valid(ai_leg):
		ai_leg.queue_free()
	
	# Add new control components
	for scene_path in control_configs[setting]:
		player_ship.add_child(load(scene_path).instantiate())

# Transition from attract mode to playing state
func _transition_to_playing(setting: Controls) -> void:
	_stop_attract_mode()
	
	control_setting = setting
	
	# Remove attract mode ship
	if has_node("Player"):
		player_ship.queue_free()
		await get_tree().process_frame
	
	# Reset game state
	current_wave = 0
	current_score = 0
	current_multiplier = 0
	
	super.start_game()
	
	# Update UI
	$Interface.hide_element(CommonEnums.Element.ATTRACT_TEXT)
	$Interface.show_element(CommonEnums.Element.LIVES)
	$Interface.show_element(CommonEnums.Element.POINTS)
	$Interface.show_element(CommonEnums.Element.MULTIPLIER)
	
	# Clear existing asteroids
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		asteroid.queue_free()
	
	await get_tree().process_frame
	await _respawn_ship($LivesCounter.max_lives, 0)

# Game start is handled by _transition_to_playing when selecting control type
func start_game():
	pass

# Handle player ship death
func _on_ship_died() -> void:
	$LivesCounter.lose_life()

# Wait until safe zone is clear of asteroids and bullets
func _wait_for_safe_zone() -> void:
	var safe_zone_radius = SAFE_ZONE_RADIUS
	var center = SCREEN_CENTER
	
	while true:
		var is_safe = true
		
		# Check asteroids
		for asteroid in get_tree().get_nodes_in_group("asteroids"):
			if asteroid.global_position.distance_to(center) < safe_zone_radius:
				is_safe = false
				break
		
		# Check bullets
		if is_safe:
			for bullet in get_tree().get_nodes_in_group("bullets"):
				if bullet.global_position.distance_to(center) < safe_zone_radius:
					is_safe = false
					break
		
		if is_safe:
			break
		
		await get_tree().process_frame

# Respawn player ship after death
func _respawn_ship(new_lives, timer) -> void:
	await _create_and_setup_ship(timer)
	
	if new_lives < 1:
		return
	
	# Add player controls
	player_ship.add_child(PLAYER_CONTROLS.instantiate())
	_load_controls(control_setting)
	player_ship.tree_exited.connect(_on_ship_died)

# Spawn ship for attract mode (AI controlled)
func _spawn_attract_ship() -> void:
	await _create_and_setup_ship(RESPAWN_DELAY)
	
	ai_brain = null
	ai_leg = null
	
	# Add AI control components
	player_ship.add_child(ATTRACT_ROTATION.instantiate())
	player_ship.add_child(ATTRACT_AI.instantiate())
	
	# Get references to AI components
	ai_brain = player_ship.get_node("AimAi")
	ai_leg = player_ship.get_node("RotationTarget")
	
	# Set initial AI target
	if ai_brain:
		var asteroids = get_tree().get_nodes_in_group("asteroids")
		if asteroids.size() > 0:
			ai_brain.set_target_node(asteroids[0])
	
	_spawning_attract_ship = false

# Create and configure ship instance
func _create_and_setup_ship(timer):
	if not is_inside_tree():
		return
	
	if player_spawning:
		return
	
	player_spawning = true
	
	# Create ship at center
	player_ship = SHIP_SCENE.instantiate()
	player_ship.name = "Player"
	player_ship.global_position = SCREEN_CENTER
	player_ship.rotation = -PI / 2
	
	# Add gun and screen wrap
	var new_gun = GUN.instantiate()
	new_gun.ammo = BULLET
	player_ship.add_child(new_gun)
	player_ship.add_child(SCREEN_WRAP.instantiate())
	
	# Connect gun signal
	gun = player_ship.get_node("GunSimple")	
	gun.target_hit.connect(_on_bullet_hit)
	
	# Wait for timer and safe zone
	await get_tree().create_timer(timer).timeout	
	await _wait_for_safe_zone()
	
	# Add ship to scene
	add_child(player_ship)	
	player_spawning = false

# Handle asteroid destruction and award points
func _on_asteroid_died(asteroid: Node) -> void:	
	if asteroid.has_meta("killed_by_bullet"):
		var base_score: int
		match asteroid.initial_size:
			2: base_score = 1
			1: base_score = 2
			0: base_score = 3
		
		add_score(base_score * current_multiplier)

# Spawn a wave of asteroids
func _spawn_wave() -> void:
	var count = current_wave + WAVE_BASE_COUNT
	for i in count:
		var asteroid = ASTEROID_SCENE.instantiate()
		
		# Spawn in circle around screen
		var spawn_angle = randf() * TAU
		asteroid.position = Vector2.from_angle(spawn_angle) * SPAWN_RADIUS + SCREEN_CENTER
		
		# Set speed based on size
		var speed: float
		match asteroid.initial_size:
			asteroid.Size.LARGE:  speed = randf_range(15.0, 35.0)
			asteroid.Size.MEDIUM: speed = randf_range(30.0, 55.0)
			asteroid.Size.SMALL:  speed = randf_range(50.0, 80.0)
		
		# Set velocity toward center with some randomness
		var inward_angle = spawn_angle + PI + randf_range(-0.5, 0.5)
		asteroid.initial_velocity = Vector2.from_angle(inward_angle) * speed
		
		add_child(asteroid)
	current_wave += 1

# Connect asteroid death signals when spawned
func _on_node_added(node: Node) -> void:
	if node.is_in_group("asteroids") and node.has_node("Health"):
		var health = node.get_node("Health")
		health.zero_health.connect(_on_asteroid_died)
