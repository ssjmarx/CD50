# Wave spawner. Instantiates entities in patterns (screen edges, center, grid, position)
# with optional stagger timing, safe zones, and component/property attachment.

extends UniversalComponent2D

# Spawn scene and pattern
@export var spawn_scene: PackedScene
@export var spawn_pattern: CommonEnums.SpawnPattern = CommonEnums.SpawnPattern.SCREEN_EDGES
@export var spawn_count_equation: String = "3 + wave_number"
@export var spawn_radius: float = 320.0
@export var spawn_spacing: float
@export var stagger_delay: float = 0.1
@export var director: Node

# Attached components and property overrides
@export var spawn_components: Array[PackedScene] = []
@export var property_overrides: Array[PropertyOverride] = []
@export var spawn_groups: Array[String] = []
@export var spawn_collision_groups: Array[String] = []

# Safe zone configuration
@export var use_safe_zone: bool = false
@export var unsafe_groups: Array[String] = ["enemies", "asteroids"]
@export var safety_radius: float = 100.0 

# Grid configuration
@export var grid_width: int = 16
@export var grid_height: int = 8
@export var grid_columns: int = 32
@export var grid_rows: int = 6
@export var grid_spacing: int = 3
@export var grid_health_by_row: bool = true
@export var grid_health_max: int = 6
@export var grid_score_by_row: bool = false
@export var grid_score_max: int = 6

# Initial velocity configuration
@export var initial_velocity: Vector2 = Vector2.ZERO
@export var use_random_angle: bool = false
@export var random_angle_min: float = 0.0
@export var random_angle_max: float = TAU
@export var random_flip_h: bool = false
@export var random_flip_v: bool = false

# Runtime state
var _expression: Expression
var _spawn_queue: Array[int] = []
var _spawn_timer: float = 0.0
var _spawn_wave_num: int = 0

# Parse spawn count expression and connect to wave signal
func _ready() -> void:
	_expression = Expression.new()
	game.spawning_wave.connect(_on_spawning_wave)
	set_process(false)

# Process-driven spawn queue: spawn one entity per stagger interval
func _process(delta: float) -> void:
	if _spawn_queue.is_empty():
		set_process(false)
		return
	_spawn_timer -= delta
	while _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
		var index: int = _spawn_queue.pop_front()
		var remaining: int = _spawn_queue.size()
		_spawn_one(_spawn_wave_num, index, index + remaining + 1)
		_spawn_timer += stagger_delay

# Determine spawn count and stagger-spawn entities when a wave begins
func _on_spawning_wave(signaller = game, wave_number: int = 0) -> void:
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
	if director != null and signaller != director and signaller != game:
		return
	
	var spawn_count: int
	if spawn_pattern == CommonEnums.SpawnPattern.GRID:
		spawn_count = grid_columns * grid_rows
	else:
		_expression.parse(spawn_count_equation, ["wave_number"])
		spawn_count = _expression.execute([wave_number])
	
	if use_safe_zone:
		await _wait_for_safe_zone()
	
	_spawn_queue.clear()
	for i in spawn_count:
		_spawn_queue.append(i)
	_spawn_wave_num = wave_number
	_spawn_timer = 0.0
	set_process(true)

# Instantiate and position a single enemy, attach components/properties/groups
func _spawn_one(wave_num: int, index: int, total: int) -> void:
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
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

			if grid_score_by_row:
				enemy.get_node("ScoreOnDeath").base_score = max(1, grid_score_max - row)

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
		var target: Node
		if override.node_path:
			target = enemy.get_node(override.node_path)
		else:
			target = enemy
		var value = override.value
		if value is Array and target[override.property_name] is Array:
			target[override.property_name].assign(value)
		else:
			target[override.property_name] = value
	
	for group in spawn_groups:
		enemy.add_to_group(group)
		GroupCache.mark_dirty(group)
	
	for group in spawn_collision_groups:
		enemy.collision_groups.append(group)
	
	game.add_child(enemy)
	
	# Emit completion signal on last spawn
	if index == total - 1:
		game.spawning_wave_complete.emit(wave_num)

# Wait until no unsafe-group entities are within safety_radius of the spawner
func _wait_for_safe_zone() -> void:
	while true:
		var is_safe = true
		for group in unsafe_groups:
			for entity in get_group_nodes(group):
				if global_position.distance_to(entity.global_position) < safety_radius:
					is_safe = false
					break
			if not is_safe:
				break
		if is_safe:
			return
		await get_tree().process_frame
