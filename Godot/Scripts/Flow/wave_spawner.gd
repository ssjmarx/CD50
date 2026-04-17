extends UniversalComponent

@export var spawn_scene: PackedScene
@export var spawn_pattern: CommonEnums.SpawnPattern = CommonEnums.SpawnPattern.SCREEN_EDGES
@export var spawn_count_equation: String = "3 + wave_number"
@export var spawn_radius: float = 320.0
@export var spawn_spacing: float
@export var stagger_delay: float = 0.1
@export var director: Node
@export var spawn_at_game_start: bool = false
@export var property_overrides: Array[PropertyOverride] = []

# grid configuration, only relevant if using grid spawning
@export var grid_width = 16
@export var grid_height = 8
@export var grid_columns = 32
@export var grid_rows = 6
@export var grid_spacing = 3

# initial velocity configuration
@export var initial_velocity: Vector2 = Vector2.ZERO
@export var use_random_angle: bool = false
@export var random_angle_min: float = 0.0
@export var random_angle_max: float = TAU
@export var random_flip_h: bool = false
@export var random_flip_v: bool = false

var expression: Expression

func _ready() -> void:
	expression = Expression.new()
	game.spawning_wave.connect(_on_spawning_wave)

	if spawn_at_game_start:
		game.on_game_start.connect(_on_spawning_wave)

func _on_spawning_wave(signaller = game, wave_number: int = 0) -> void:
	if director != null and signaller != director and signaller != game:
		return
	
	expression.parse(spawn_count_equation)
	var spawn_count = expression.execute([wave_number])
	
	for i in spawn_count:
		var delay = i * stagger_delay
		get_tree().create_timer(delay).timeout.connect(func(): _spawn_one(wave_number, i, spawn_count))

func _spawn_one(wave_num: int, index: int, total: int) -> void:
	var enemy = spawn_scene.instantiate()
	
	match spawn_pattern:
		CommonEnums.SpawnPattern.SCREEN_EDGES:
			var angle = randf() * TAU
			enemy.position = Vector2.from_angle(angle) * spawn_radius + Vector2(320, 180)
		CommonEnums.SpawnPattern.SCREEN_CENTER:
			enemy.position = Vector2(320, 180)
		CommonEnums.SpawnPattern.GRID:
			# fill this with the grid logic from breakout
			pass
	
	if initial_velocity != Vector2.ZERO:
		enemy.velocity = initial_velocity
		if use_random_angle:
			var speed = enemy.velocity.length()
			var angle = Vector2.from_angle(randf_range(random_angle_min, random_angle_max))
			enemy.velocity = angle * speed

	if random_flip_h:
		enemy.velocity.x *= [-1, 1].pick_random()
	
	if random_flip_v:
		enemy.velocity.y *= [-1, 1].pick_random()
	
	for override in property_overrides:
		var target = enemy.get_node(override.node_path)
		target[override.property_name] = override.value
	
	game.add_child(enemy)
	
	if index == total - 1:
		game.spawning_wave_complete.emit(wave_num)
