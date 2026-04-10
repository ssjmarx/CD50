extends Node2D

var game_started: bool = false
var game_over:bool = false

@onready var startup_text_1 = $"UI/Startup Text"
@onready var startup_text_2 = $"UI/Startup Text/Continue Text"
@onready var player_ship = $Player
@onready var p1_win_text = $UI/"Win Text"
@onready var p1_lose_text = $UI/"Lose Text"
@onready var continue_text = $UI/"Continue Text"
@onready var points_number = $UI/points/pointsnumber
@onready var multiplier_number = $UI/multiplier/multipliernumber
@onready var death_sound = $AudioStreamPlayer2D
@onready var gun = $Player/GunSimple

func _ready() -> void:
	gun.target_hit.connect(_on_bullet_hit)

func _process(_delta):
	if not game_started:
		if Input.is_action_just_pressed("number_1"):
			_load_original_controls()
			game_started = true
		elif Input.is_action_just_pressed("number_2"):
			_load_modern_controls()
			game_started = true

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _on_bullet_hit(target: Node) -> void:
	if target.has_node("health"):
		target.get_node("health").reduce_health(1)

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
	_start_game()

func _start_game():
	startup_text_1.hide()
	startup_text_2.hide()
	player_ship.tree_exited.connect(_on_ship_died)

func _on_ship_died() -> void:
	p1_lose()

func p1_win() -> void:
	game_over = true
	p1_win_text.visible = true
	continue_text.visible = true

func p1_lose() -> void:
	game_over = true
	p1_lose_text.visible = true
	continue_text.visible = true
