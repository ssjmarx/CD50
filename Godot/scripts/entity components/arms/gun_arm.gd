## spawns a projectile on a fire signal
class_name GunArm extends CDEntityComponent

@export var bullet_scene: PackedScene
@export var pool: CDObjectPool = null
@export var cooldown: float = 0.3
@export var spawn_context: CDSpawnContext = null
@export var inherit_rotation: bool = true

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"shoot"]

var _last_fire_time: float = -999.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in fire_signals:
		entity.connect(sig, _on_fire)

func _on_fire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_fire_time < cooldown:
		return
	_last_fire_time = now

	if bullet_scene == null:
		return

	var projectile: CDEntity

	if pool:
		projectile = pool.acquire()
		if projectile == null:
			return
		projectile.global_position = entity.global_position
	else:
		projectile = bullet_scene.instantiate()
		projectile.global_position = entity.global_position

	CDUtilities.apply_spawn_context(projectile, spawn_context)

	if inherit_rotation:
		projectile.rotation = entity.rotation

	if pool:
		projectile.activate()
	else:
		game.add_child(projectile)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in fire_signals:
		if entity.is_connected(sig, _on_fire):
			entity.disconnect(sig, _on_fire)
