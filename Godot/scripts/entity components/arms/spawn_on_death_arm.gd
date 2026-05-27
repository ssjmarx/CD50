## spawns entities when the parent entity dies
class_name SpawnOnDeathArm extends CDEntityComponent

@export var spawn_scene: PackedScene
@export var spawn_count: int = 1
@export var pool: CDObjectPool = null
@export var spawn_context: CDSpawnContext = null
@export var inherit_position: bool = true
@export var inherit_velocity: bool = false

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in death_signals:
		entity.connect(sig, _on_death)

func _on_death() -> void:
	for i in spawn_count:
		_spawn_one(i)

func _spawn_one(_index: int) -> void:
	if spawn_scene == null:
		return

	var spawned: CDEntity

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

	CDUtilities.apply_spawn_context(spawned, spawn_context)

	if inherit_velocity:
		spawned.velocity += entity.velocity

	if pool:
		spawned.activate()
	else:
		game.add_child(spawned)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		if entity.is_connected(sig, _on_death):
			entity.disconnect(sig, _on_death)
