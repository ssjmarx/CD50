## CDStageTrapdoor
## Base class for all stage-level spawners
## Implements Trigger → Queue → Stagger → Spawn lifecycle with telefrag and safe zone support

class_name CDStageTrapdoor extends CDGameComponent

## seconds between each entity spawn in a wave
@export var stagger_delay: float = 0.1

## set to CDObjectPool for pooled spawning, null for fresh instantiate
@export var pool: CDObjectPool = null

## optional resource for velocity/rotation applied before entity enters tree
@export var spawn_context: CDSpawnContext = null

## array of scenes to cycle through. If empty, falls back to _get_spawn_scene().
@export var spawn_scenes: Array[PackedScene] = []

## seconds to wait before starting the spawn after trigger signal fires
@export var trigger_delay: float = 0.0

@export_group("Blackboard Keys")
## key for reading current wave number from game blackboard
@export var wave_key: StringName = &"wave_number"

## kill overlapping entities at spawn point before spawning
@export var telefrag: bool = false
@export var telefrag_targets: Array[StringName] = [&"enemies"]

## game bus signals that trigger a spawn wave
@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"wave_start"]
@export var safe_signals: Array[StringName] = [&"zone_safe"]
@export var unsafe_signals: Array[StringName] = [&"zone_unsafe"]

## game bus signals emitted when all entities in a wave have spawned
@export_group("Emit Signals")
@export var on_spawning_complete: Array[StringName] = [&"spawning_complete"]

## indices remaining to spawn this wave
var _spawn_queue: Array[int] = []
## countdown timer for stagger delay
var _spawn_timer: float = 0.0
## current wave number from the trigger signal
var _current_wave: int = 0
## paused while a SafeZoneMark reports the spawn area is occupied
var _zone_is_safe: bool = true
## countdown for trigger_delay before spawning begins
var _delay_remaining: float = 0.0
## wave number saved during delay phase
var _pending_wave: int = 0

## disable processing until a trigger signal arrives
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	set_physics_process(false)

## connect all trigger, safe, and unsafe signals to the game bus
func _on_initialize() -> void:
	for sig in trigger_signals:
		if trigger_delay > 0.0:
			bus_connect(sig, _on_delayed_trigger)
		else:
			bus_connect(sig, _on_trigger)
	for sig in safe_signals:
		bus_connect(sig, _on_zone_safe)
	for sig in unsafe_signals:
		bus_connect(sig, _on_zone_unsafe)

## --- Delay Gate ---

## receives trigger signal and enters delay phase before spawning
func _on_delayed_trigger() -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return
	_pending_wave = game.blackboard.get(wave_key, 0)
	_delay_remaining = trigger_delay
	set_physics_process(true)

## --- Stagger Loop ---

## drain spawn queue one entity at a time with stagger delay
func _physics_process(delta: float) -> void:
	## phase 1: countdown trigger_delay before spawning
	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		if _delay_remaining <= 0.0:
			_delay_remaining = 0.0
			_on_trigger()
		return

	if _spawn_queue.is_empty():
		set_physics_process(false)
		return

	if not _zone_is_safe:
		return

	## spawn as many as the timer allows this frame
	_spawn_timer -= delta
	while _spawn_timer <= 0.0 and not _spawn_queue.is_empty() and _zone_is_safe:
		var index: int = _spawn_queue.pop_front()
		_spawn_one(index)
		_spawn_timer += stagger_delay

	## emit completion signal when entire wave is done
	if _spawn_queue.is_empty():
		game.blackboard["spawned_wave"] = _current_wave
		for sig in on_spawning_complete:
			game.bus_emit(sig)

## --- Virtual Methods for Concrete Trapdoors ---

## override to return how many entities to spawn for a given wave
func _get_spawn_count(_wave_number: int) -> int:
	return 0

## override to populate _spawn_queue for a given wave.
## Default impl fills 0.._get_spawn_count-1; subclasses (e.g. GridTrapdoor)
## override this instead of _on_trigger when they need custom queue logic
## (skipping slots, data-driven layouts, etc.).
func _populate_spawn_queue(wave_number: int) -> void:
	var total: int = _get_spawn_count(wave_number)
	_spawn_queue.clear()
	for i in total:
		_spawn_queue.append(i)

## override to return world position for entity at index
func _get_spawn_position(_index: int, _total: int) -> Vector2:
	return global_position

## override to return the PackedScene for entity at index (null = skip slot)
func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	push_error("CDStageTrapdoor is abstract — override _get_spawn_scene() in a concrete trapdoor (PointTrapdoor, EdgeTrapdoor, GridTrapdoor)")
	return null

## --- Trigger Handling ---

## receive trigger signal, delegate queue population to the virtual, start stagger loop
func _on_trigger() -> void:
	if game.current_state == CDEnums.GameState.GAME_OVER:
		return

	_current_wave = game.blackboard.get(wave_key, 0)
	_populate_spawn_queue(_current_wave)

	_spawn_timer = 0.0
	set_physics_process(true)

## --- Spawn Execution ---

## acquire or instantiate a single entity, apply context, and activate
func _spawn_one(index: int) -> void:
	var total := _spawn_queue.size() + 1
	var scene: PackedScene
	if spawn_scenes.size() > 0:
		scene = spawn_scenes[index % spawn_scenes.size()]
	else:
		scene = _get_spawn_scene(index, total)

	if scene == null:
		return

	var spawn_position: Vector2 = _get_spawn_position(index, total)
	var entity: CDEntity

	## acquire from pool or instantiate fresh
	if pool:
		entity = pool.acquire()
		if entity == null:
			return
		entity.global_position = spawn_position
	else:
		entity = scene.instantiate()
		entity.global_position = spawn_position

	if telefrag:
		_telefrag_at(spawn_position, entity)

	CDUtilities.apply_spawn_context(entity, spawn_context)

	## activate: add to tree (fresh) or wake from pool
	if pool:
		entity.activate()
	else:
		game.add_child(entity)

## --- Telefrag ---

## point-query at spawn location, kill anything that overlaps
func _telefrag_at(pos: Vector2, _exclude: CDEntity) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_exclude.get_rid()]

	## check all bodies at spawn point
	var results := space_state.intersect_point(query)
	for result in results:
		var body = result["collider"]
		if not body or not is_instance_valid(body):
			continue
		if telefrag_targets.is_empty() or _matches_telefrag_targets(body):
			print("telefrag!")
			body.emit_signal("request_deactivate")

## --- Safe Zone ---

## on zone safe
func _on_zone_safe() -> void:
	_zone_is_safe = true

## on zone unsafe
func _on_zone_unsafe() -> void:
	_zone_is_safe = false

## --- Internal Helpers ---

## check if a body belongs to any of the telefrag target groups
func _matches_telefrag_targets(body: Node) -> bool:
	for group in telefrag_targets:
		if body.is_in_group(group):
			return true
	return false
