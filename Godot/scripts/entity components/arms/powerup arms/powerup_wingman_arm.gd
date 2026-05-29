# PowerupWingmanArm
# Spawns a companion entity at the player's position when a matching powerup is received
# Checks powerup_id before spawning, supports object pooling and spawn offset

class_name PowerupWingmanArm extends CDEntityComponent

# powerup identifier to match against
@export var powerup_id: StringName = &"wingman"

# companion scene to spawn
@export var companion_scene: PackedScene

# optional object pool for companions
@export var pool: CDObjectPool = null

# optional spawn context to apply to the companion
@export var spawn_context: CDSpawnContext = null

# position offset from entity when spawning
@export var spawn_offset: Vector2 = Vector2(24, 0)

# add parent's velocity to the companion
@export var inherit_velocity: bool = false

@export_group("Listen Signals")
@export var activate_signals: Array[StringName] = [&"receive_powerup"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect activate signals
func _on_initialize() -> void:
	for sig in activate_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_activate)

# only spawn if the received powerup_id matches ours
func _on_activate(received_id: StringName, _source: Variant = null) -> void:
	if received_id != powerup_id:
		return
	_spawn_companion()

# spawn the companion entity from scene or pool
func _spawn_companion() -> void:
	if companion_scene == null:
		return

	var spawned: CDEntity

	# acquire from pool or instantiate fresh
	if pool:
		spawned = pool.acquire()
		if spawned == null:
			return
		spawned.global_position = entity.global_position + spawn_offset
	else:
		spawned = companion_scene.instantiate()
		spawned.global_position = entity.global_position + spawn_offset

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

# disconnect all activate signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in activate_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_activate):
			entity.disconnect(sig, _on_activate)