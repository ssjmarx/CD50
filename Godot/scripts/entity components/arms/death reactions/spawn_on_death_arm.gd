# SpawnOnDeathArm
# Spawns entities at the parent's position when it dies
# Supports object pooling, spawn context, and position/velocity inheritance

class_name SpawnOnDeathArm extends CDEntityComponent

# scene to spawn on death
@export var spawn_scene: PackedScene

# how many entities to spawn
@export var spawn_count: int = 1

# optional object pool for spawned entities
@export var pool: CDObjectPool = null

# optional spawn context to apply to each spawned entity
@export var spawn_context: CDSpawnContext = null

# copy parent's global_position to each spawn
@export var inherit_position: bool = true

# add parent's velocity to each spawn
@export var inherit_velocity: bool = false

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect death signals
func _on_initialize() -> void:
	for sig in death_signals:
		entity.connect(sig, _on_death)

# spawn the configured number of entities
func _on_death() -> void:
	for i in spawn_count:
		_spawn_one(i)

# spawn a single entity from scene or pool
func _spawn_one(_index: int) -> void:
	if spawn_scene == null:
		return

	var spawned: CDEntity

	# acquire from pool or instantiate fresh
	if pool:
		spawned = pool.acquire()
		if spawned == null:
			return
		if inherit_position:
			spawned.global_position = entity.global_position
	else:
		spawned = spawn_scene.instantiate()
		if inherit_position:
			spawned.global_position = entity.global_position

	# apply optional spawn context
	CDUtilities.apply_spawn_context(spawned, spawn_context)

	# optionally inherit parent velocity
	if inherit_velocity:
		spawned.velocity += entity.velocity

	# activate pooled entity or add to scene tree
	if pool:
		spawned.activate()
	else:
		game.add_child(spawned)

# disconnect all death signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		if entity.is_connected(sig, _on_death):
			entity.disconnect(sig, _on_death)