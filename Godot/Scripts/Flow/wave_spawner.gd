extends Node2D

@export var spawn_scene: PackedScene
@export var spawn_pattern: SpawnPattern = SpawnPattern.SCREEN_EDGES
@export var spawn_count_equation: String = "3 + wave_number"
@export var spawn_radius: float = 320.0
@export var spawn_spacing: float
@export var stagger_delay: float = 0.1
@export var director: Node

# grid configuration, only relevant if using grid spawning
@export var grid_width = 16
@export var grid_height = 8
@export var grid_columns = 32
@export var grid_rows = 6
@export var grid_spacing = 3

var expression: Expression

@onready var parent = get_parent()

enum SpawnPattern {
	SCREEN_EDGES,
	SCREEN_CENTER,
	GRID
}

func _ready():
	expression = Expression.new()
	parent.spawning_wave.connect(_on_spawning_wave)

func _on_spawning_wave(signaller, wave_number: int):
	if signaller != director:
		return
	
	expression.parse(spawn_count_equation)
	var spawn_count = expression.execute([wave_number])
	
	for i in spawn_count:
		var delay = i * stagger_delay
		get_tree().create_timer(delay).timeout.connect(
			func(): _spawn_one(wave_number, i, spawn_count)
		)

func _spawn_one(wave_num: int, index: int, total: int):
	var enemy = spawn_scene.instantiate()
	
	match spawn_pattern:
		SpawnPattern.SCREEN_EDGES:
			var angle = randf() * TAU
			enemy.position = Vector2.from_angle(angle) * spawn_radius + Vector2(320, 180)
		SpawnPattern.SCREEN_CENTER:
			enemy.position = Vector2(320, 180)
		SpawnPattern.GRID:
			# fill this with the grid logic from breakout
			pass
	
	add_child(enemy)
	
	if index == total - 1:
		parent.spawning_wave_complete.emit(wave_num)
