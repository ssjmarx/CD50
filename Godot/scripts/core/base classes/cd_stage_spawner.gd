## base class for all stage spawners
class_name CDStageSpawner extends CDGameComponent

@export var stagger_delay: float = 0.1
@export var pool: CDObjectPool = null
@export var spawn_context: CDSpawnContext = null
@export var telefrag: bool = false
@export var telefrag_targets: Array[StringName] = [&"enemies"]
@export var safe_zone: CDSafeZone = null

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"wave_start"]

@export_group("Emit Signals")
@export var on_spawning_complete: Array[StringName] = [&"spawning_complete"]

var _spawn_queue: Array[int] = []
var _spawn_timer: float = 0.0
var _current_wave: int = 0
var _zone_is_safe: bool = true

## set up and then pause until signalled
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	set_process(false)

func _on_initialize() -> void:
	for sig in trigger_signals:
		game.bus_connect(sig, _on_trigger)

	if safe_zone:
		safe_zone.zone_safe.connect(_on_zone_safe)
		safe_zone.zone_unsafe.connect(_on_zone_unsafe)

## queue and stagger spawns for clean performance
func _process(delta: float) -> void:
	if _spawn_queue.is_empty():
		set_process(false)
		return

	if not _zone_is_safe:
		return

	_spawn_timer -= delta
	while _spawn_timer <= 0.0 and not _spawn_queue.is_empty() and _zone_is_safe:
		var index: int = _spawn_queue.pop_front()
		_spawn_one(index)
		_spawn_timer += stagger_delay

	if _spawn_queue.is_empty():
		for sig in on_spawning_complete:
			game.bus_emit(sig, [_current_wave])

### virtual methods for derived spawners

func _get_spawn_count(_wave_number: int) -> int:
	return 0

func _get_spawn_position(_index: int, _total: int) -> Vector2:
	return global_position

func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	push_error("CDStageSpawner is abstract — override _get_spawn_scene() in a concrete spawner (PointSpawner, EdgeSpawner, GridSpawner)")
	return null

## receives the trigger signal, wave number passed by wave card
func _on_trigger(wave_number: int = 0) -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return

	_current_wave = wave_number
	var total: int = _get_spawn_count(wave_number)

	_spawn_queue.clear()
	for i in total:
		_spawn_queue.append(i)

	_spawn_timer = 0.0
	set_process(true)

## spawn a single entity
func _spawn_one(index: int) -> void:
	var total := _spawn_queue.size() + 1
	var scene: PackedScene = _get_spawn_scene(index, total)

	# null scene = skip this slot
	if scene == null:
		return

	var spawn_position: Vector2 = _get_spawn_position(index, total)
	var entity: CDEntity

	# acquire from pool or instantiate fresh
	if pool:
		entity = pool.acquire()
		if entity == null:
			return
		entity.global_position = spawn_position
	else:
		entity = scene.instantiate()
		entity.global_position = spawn_position

	# telefrag: kill overlapping entities before the new one enters
	if telefrag and not telefrag_targets.is_empty():
		_telefrag_at(spawn_position, entity)

	# apply spawn context (velocity, rotation) before entity enters tree
	_apply_spawn_context(entity)

	# activate: add to tree (fresh) or wake from pool
	if pool:
		entity.activate()
	else:
		game.add_child(entity)

## applies CDSpawnContext to entity. runs before add_child / activate
func _apply_spawn_context(entity: CDEntity) -> void:
	if spawn_context == null:
		return

	entity.velocity = spawn_context.velocity

	if spawn_context.use_random_angle:
		var speed := entity.velocity.length()
		var angle := Vector2.from_angle(randf_range(spawn_context.random_angle_min, spawn_context.random_angle_max))
		entity.velocity = angle * speed

	if spawn_context.random_flip_h:
		entity.velocity.x *= [-1, 1].pick_random()

	if spawn_context.random_flip_v:
		entity.velocity.y *= [-1, 1].pick_random()

	entity.rotation = spawn_context.rotation

## does a point query at the spawn location, anything that collides get killed
func _telefrag_at(pos: Vector2, _exclude: CDEntity) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_exclude.get_rid()]

	var results := space_state.intersect_point(query)
	for result in results:
		var body = result["collider"]
		if not body or not is_instance_valid(body):
			continue
		for group in telefrag_targets:
			if body.is_in_group(group):
				body.emit_signal("request_deactivate")
				break

func _on_zone_safe() -> void:
	_zone_is_safe = true

func _on_zone_unsafe() -> void:
	_zone_is_safe = false
