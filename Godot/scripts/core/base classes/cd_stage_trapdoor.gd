# CDStageTrapdoor
# Base class for all stage-level spawners
# Implements Trigger → Queue → Stagger → Spawn lifecycle with telefrag and safe zone support

class_name CDStageTrapdoor extends CDGameComponent

# seconds between each entity spawn in a wave
@export var stagger_delay: float = 0.1

# set to CDObjectPool for pooled spawning, null for fresh instantiate
@export var pool: CDObjectPool = null

# optional resource for velocity/rotation applied before entity enters tree
@export var spawn_context: CDSpawnContext = null

# kill overlapping entities at spawn point before spawning
@export var telefrag: bool = false
@export var telefrag_targets: Array[StringName] = [&"enemies"]

# game bus signals that trigger a spawn wave
@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"wave_start"]
@export var safe_signals: Array[StringName] = [&"zone_safe"]
@export var unsafe_signals: Array[StringName] = [&"zone_unsafe"]

# game bus signals emitted when all entities in a wave have spawned
@export_group("Emit Signals")
@export var on_spawning_complete: Array[StringName] = [&"spawning_complete"]

# indices remaining to spawn this wave
var _spawn_queue: Array[int] = []
# countdown timer for stagger delay
var _spawn_timer: float = 0.0
# current wave number from the trigger signal
var _current_wave: int = 0
# paused while a SafeZoneMark reports the spawn area is occupied
var _zone_is_safe: bool = true

# disable processing until a trigger signal arrives
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	set_physics_process(false)

# connect all trigger, safe, and unsafe signals to the game bus
func _on_initialize() -> void:
	for sig in trigger_signals:
		game.bus_connect(sig, _on_trigger)
	for sig in safe_signals:
		game.bus_connect(sig, _on_zone_safe)
	for sig in unsafe_signals:
		game.bus_connect(sig, _on_zone_unsafe)

# --- Stagger Loop ---

# drain spawn queue one entity at a time with stagger delay
func _physics_process(delta: float) -> void:
	if _spawn_queue.is_empty():
		set_physics_process(false)
		return

	# hold the queue while spawn zone is occupied
	if not _zone_is_safe:
		return

	# spawn as many as the timer allows this frame
	_spawn_timer -= delta
	while _spawn_timer <= 0.0 and not _spawn_queue.is_empty() and _zone_is_safe:
		var index: int = _spawn_queue.pop_front()
		_spawn_one(index)
		_spawn_timer += stagger_delay

	# emit completion signal when entire wave is done
	if _spawn_queue.is_empty():
		for sig in on_spawning_complete:
			game.bus_emit(sig, [_current_wave])

# --- Virtual Methods for Concrete Trapdoors ---

# override to return how many entities to spawn for a given wave
func _get_spawn_count(_wave_number: int) -> int:
	return 0

# override to return world position for entity at index
func _get_spawn_position(_index: int, _total: int) -> Vector2:
	return global_position

# override to return the PackedScene for entity at index (null = skip slot)
func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	push_error("CDStageTrapdoor is abstract — override _get_spawn_scene() in a concrete trapdoor (PointTrapdoor, EdgeTrapdoor, GridTrapdoor)")
	return null

# --- Trigger Handling ---

# receive trigger signal, queue all spawn indices, start stagger loop
func _on_trigger(wave_number: int = 0) -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return

	_current_wave = wave_number
	var total: int = _get_spawn_count(wave_number)

	# build queue of indices to spawn
	_spawn_queue.clear()
	for i in total:
		_spawn_queue.append(i)

	_spawn_timer = 0.0
	set_physics_process(true)

# --- Spawn Execution ---

# acquire or instantiate a single entity, apply context, and activate
func _spawn_one(index: int) -> void:
	var total := _spawn_queue.size() + 1
	var scene: PackedScene = _get_spawn_scene(index, total)

	# null scene means skip this slot (used by grid spawners for empty cells)
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
	if telefrag:
		_telefrag_at(spawn_position, entity)

	# apply spawn context (velocity, rotation) before entity enters tree
	CDUtilities.apply_spawn_context(entity, spawn_context)

	# activate: add to tree (fresh) or wake from pool
	if pool:
		entity.activate()
	else:
		game.add_child(entity)

# --- Telefrag ---

# point-query at spawn location, kill anything that overlaps
func _telefrag_at(pos: Vector2, _exclude: CDEntity) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_exclude.get_rid()]

	# check all bodies at spawn point
	var results := space_state.intersect_point(query)
	for result in results:
		var body = result["collider"]
		if not body or not is_instance_valid(body):
			continue
		# kill if no target filter or if body matches filter
		if telefrag_targets.is_empty() or _matches_telefrag_targets(body):
			print("telefrag!")
			body.emit_signal("request_deactivate")

# --- Safe Zone ---

func _on_zone_safe() -> void:
	_zone_is_safe = true

func _on_zone_unsafe() -> void:
	_zone_is_safe = false

# --- Internal Helpers ---

# check if a body belongs to any of the telefrag target groups
func _matches_telefrag_targets(body: Node) -> bool:
	for group in telefrag_targets:
		if body.is_in_group(group):
			return true
	return false
