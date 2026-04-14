extends "res://Scripts/Core/universal_game_script.gd"

const SHIP_SCENE = preload("res://Scenes/Bodies/triangle_ship.tscn")
const ASTEROID_SCENE = preload("res://Scenes/Bodies/asteroid.tscn")

var game_started: bool = false
var points: int = 0
var multiplier:int = 0
var asteroid_count: int = 0
var current_wave: int = 1
var lives: int = 3
var control_setting: Controls
var wave_spawning: bool = false

enum Controls {
	ORIGINAL,
	MODERN
}

@onready var player_ship = $Player
@onready var gun = $Player/GunSimple

func _ready() -> void:
	super._ready()
	
	setup_collision_groups({
	"asteroids": ["asteroids", "ships"],
	"ships": ["asteroids", "bullets"],
	"bullets": ["ships", "asteroids"]
	})
	
	gun.target_hit.connect(_on_bullet_hit)

func _physics_process(_delta: float) -> void:
	if not game_started:
		if Input.is_action_just_pressed("number_1"):
			control_setting = Controls.ORIGINAL
			_load_original_controls()
			game_started = true
		elif Input.is_action_just_pressed("number_2"):
			control_setting = Controls.MODERN
			_load_modern_controls()
			game_started = true
	
	var live_asteroids = get_tree().get_nodes_in_group("asteroids")
	asteroid_count = live_asteroids.size()
	
	for asteroid in live_asteroids:
		var health = asteroid.get_node("Health")
		if not health.zero_health.is_connected(_on_asteroid_died):
			health.zero_health.connect(_on_asteroid_died)
	
	#points_number.text = str(points)
	#multiplier_number.text = str(multiplier + asteroid_count)
	#lives_number.text = str(lives)

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _on_bullet_hit(target: Node) -> void:
	if target.has_node("Health"):
		target.set_meta("killed_by_bullet", true)
		target.get_node("Health").reduce_health(1)

func _load_original_controls():
	var rot = preload("res://Scenes/Legs/rotation_direct.tscn").instantiate()
	var engine = preload("res://Scenes/Legs/engine_simple.tscn").instantiate()
	player_ship.add_child(rot)
	player_ship.add_child(engine)
	_start_game()

func _load_modern_controls():
	var rot = preload("res://Scenes/Legs/rotation_target.tscn").instantiate()
	var engine = preload("res://Scenes/Legs/engine_complex.tscn").instantiate()
	var maneuvering = preload("res://Scenes/Legs/direct_acceleration.tscn").instantiate()
	var friction = preload("res://Scenes/Legs/friction_linear.tscn").instantiate()
	player_ship.add_child(rot)
	player_ship.add_child(engine)
	player_ship.add_child(maneuvering)
	player_ship.add_child(friction)
	current_wave += 4
	_start_game()

func _start_game():
	#startup_text_1.hide()
	#startup_text_2.hide()
	player_ship.tree_exited.connect(_on_ship_died)
	_spawn_wave()

func _on_ship_died() -> void:
	lives -= 1
	#lives_number.text = str(lives)
	if lives <= 0:
		p1_lose()
	else:
		_respawn_ship()

func _respawn_ship() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return
	
	player_ship = SHIP_SCENE.instantiate()
	player_ship.global_position = Vector2(320, 180)
	
	var new_gun = preload("res://Scenes/Arms/gun_simple.tscn").instantiate()
	var new_ammo = preload("res://Scenes/Bodies/bullet_wrapping.tscn")
	new_gun.ammo = new_ammo
	player_ship.add_child(new_gun)
	
	match control_setting:
		Controls.ORIGINAL:
			player_ship.add_child(preload("res://Scenes/Legs/rotation_direct.tscn").instantiate())
			player_ship.add_child(preload("res://Scenes/Legs/engine_simple.tscn").instantiate())
		Controls.MODERN:
			player_ship.add_child(preload("res://Scenes/Legs/rotation_target.tscn").instantiate())
			player_ship.add_child(preload("res://Scenes/Legs/engine_complex.tscn").instantiate())
			player_ship.add_child(preload("res://Scenes/Legs/direct_acceleration.tscn").instantiate())
			player_ship.add_child(preload("res://Scenes/Legs/friction_linear.tscn").instantiate())
	
	player_ship.add_child(preload("res://Scenes/Brains/player_control.tscn").instantiate())
	
	add_child(player_ship)
	
	gun = player_ship.get_node("GunSimple")
	gun.target_hit.connect(_on_bullet_hit)
	player_ship.tree_exited.connect(_on_ship_died)

func p1_win() -> void:
	current_state = states.GAME_OVER
	#p1_win_text.visible = true
	#continue_text.visible = true

func p1_lose() -> void:
	current_state = states.GAME_OVER
	#p1_lose_text.visible = true
	#continue_text.visible = true

func _on_asteroid_died(asteroid: Node) -> void:
	asteroid.remove_from_group("asteroids")  # ← add this
	
	asteroid_count = get_tree().get_nodes_in_group("asteroids").size()
	
	if asteroid.has_meta("killed_by_bullet"):
		var base_score: int
		match asteroid.initial_size:
			2: base_score = 1
			1: base_score = 2
			0: base_score = 3
		points += base_score * (asteroid_count + multiplier)
	#points_number.text = str(points)
	
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("asteroids").size() == 0 and not wave_spawning:
		wave_spawning = true
		await get_tree().create_timer(1).timeout
		_spawn_wave()
		wave_spawning = false

func _spawn_wave() -> void:
	var count = current_wave + 3
	for i in count:
		var asteroid = ASTEROID_SCENE.instantiate()
		
		var spawn_angle = randf() * TAU
		asteroid.position = Vector2.from_angle(spawn_angle) * 320 + Vector2(320, 180)
		
		var speed: float
		match asteroid.initial_size:
			asteroid.Size.LARGE:  speed = randf_range(15.0, 35.0)
			asteroid.Size.MEDIUM: speed = randf_range(30.0, 55.0)
			asteroid.Size.SMALL:  speed = randf_range(50.0, 80.0)

		var inward_angle = spawn_angle + PI + randf_range(-0.5, 0.5)
		asteroid.initial_velocity = Vector2.from_angle(inward_angle) * speed
		
		add_child(asteroid)
	current_wave += 1
