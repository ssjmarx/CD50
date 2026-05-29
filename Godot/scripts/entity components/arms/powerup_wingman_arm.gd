## spawns a companion entity at the player's position when a powerup is receivedd
class_name PowerupWingmanArm extends CDEntityComponent

@export var powerup_id: StringName = &"wingman"
@export var companion_scene: PackedScene
@export var pool: CDObjectPool = null
@export var spawn_context: CDSpawnContext = null
@export var spawn_offset: Vector2 = Vector2(24, 0)
@export var inherit_velocity: bool = false

@export_group("Listen Signals")
@export var activate_signals: Array[StringName] = [&"receive_powerup"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in activate_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_activate)

func _on_activate(received_id: StringName, _source: Variant = null) -> void:
	if received_id != powerup_id:
		return
	_spawn_companion()

func _spawn_companion() -> void:
	if companion_scene == null:
		return

	var spawned: CDEntity

	if pool:
		spawned = pool.acquire()
		if spawned == null:
			return
		spawned.global_position = entity.global_position + spawn_offset
	else:
		spawned = companion_scene.instantiate()
		spawned.global_position = entity.global_position + spawn_offset

	CDUtilities.apply_spawn_context(spawned, spawn_context)

	if inherit_velocity:
		spawned.velocity += entity.velocity

	if pool:
		spawned.activate()
	else:
		game.add_child(spawned)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in activate_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_activate):
			entity.disconnect(sig, _on_activate)
