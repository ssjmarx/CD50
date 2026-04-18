extends UniversalComponent2D

@export var spawn_scene: PackedScene
@export var spawn_pattern: CommonEnums.SpawnPattern = CommonEnums.SpawnPattern.SCREEN_EDGES
@export var spawn_count_equation: String = "3 + wave_number"
@export var spawn_radius: float = 320.0
@export var spawn_spacing: float
@export var stagger_delay: float = 0.1
@export var director: Node
@export var spawn_components: Array[PackedScene] = []
@export var property_overrides: Array[PropertyOverride] = []
@export var spawn_groups: Array[String] = []
@export var spawn_collision_groups: Array[String] = []

# configuration for safe zone
@export var use_safe_zone: bool = false
@export var unsafe_groups: Array[String] = ["enemies", "asteroids"]
@export var safety_radius: float = 100.0 

# grid configuration
@export var grid_width = 16
@export var grid_height = 8
@export var grid_columns = 32
@export var grid_rows = 6
@export var grid_spacing = 3
@export var grid_health_by_row: bool = true
@export var grid_health_max: int = 6

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

func _on_spawning_wave(signaller = game, wave_number: int = 0) -> void:
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
	#print("on spawning wave")
	if director != null and signaller != director and signaller != game:
		return
	
	var spawn_count: int
	if spawn_pattern == CommonEnums.SpawnPattern.GRID:
		spawn_count = grid_columns * grid_rows
	else:
		expression.parse(spawn_count_equation, ["wave_number"])
		spawn_count = expression.execute([wave_number])
	
	if use_safe_zone:
		await _wait_for_safe_zone()
	
	for i in spawn_count:
		var delay = i * stagger_delay
		get_tree().create_timer(delay).timeout.connect(func(): _spawn_one(wave_number, i, spawn_count))

func _spawn_one(wave_num: int, index: int, total: int) -> void:
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
	#print("spawn one")
	var enemy = spawn_scene.instantiate()
	
	match spawn_pattern:
		CommonEnums.SpawnPattern.SCREEN_EDGES:
			var angle = randf() * TAU
			enemy.position = Vector2.from_angle(angle) * spawn_radius + Vector2(320, 180)
		CommonEnums.SpawnPattern.SCREEN_CENTER:
			enemy.position = Vector2(320, 180)
		CommonEnums.SpawnPattern.GRID:
			var col = index % grid_columns
			@warning_ignore("integer_division")
			var row = index / grid_columns
			
			var step_x = grid_width + grid_spacing
			var step_y = grid_height + grid_spacing
			
			var total_w = grid_columns * step_x - grid_spacing
			var total_h = grid_rows * step_y - grid_spacing
			
			var origin_x = global_position.x - total_w / 2.0
			var origin_y = global_position.y - total_h / 2.0
			
			enemy.position = Vector2(
				origin_x + col * step_x + grid_width / 2.0,
				origin_y + row * step_y + grid_height / 2.0
			)

			if grid_health_by_row:
				enemy.get_node("Health").max_health = max(1, grid_health_max - row)

		CommonEnums.SpawnPattern.POSITION:
			enemy.position = global_position
	
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

	for component_scene in spawn_components:
		var component = component_scene.instantiate()
		enemy.add_child(component)
	
	for override in property_overrides:
		var target = enemy.get_node(override.node_path)
		var value = override.value
		if value is Array and target[override.property_name] is Array:
			target[override.property_name].assign(value)
		else:
			target[override.property_name] = value
	
	for group in spawn_groups:
		enemy.add_to_group(group)
	
	for group in spawn_collision_groups:
		enemy.collision_groups.append(group)
	
	game.add_child(enemy)
	
	if index == total - 1:
		game.spawning_wave_complete.emit(wave_num)

func _wait_for_safe_zone() -> void:
	while true:
		var is_safe = true
		for group in unsafe_groups:
			for entity in get_tree().get_nodes_in_group(group):
				if global_position.distance_to(entity.global_position) < safety_radius:
					is_safe = false
					break
			if not is_safe:
				break
		if is_safe:
			return
		await get_tree().process_frame
