## GunArm
## Spawns a projectile on a fire signal with cooldown and optional max bullet limit
## Supports object pooling and rotation inheritance

class_name GunArm extends CDEntityComponent

## projectile scene to spawn
@export var bullet_scene: PackedScene

## optional object pool for projectiles
@export var pool: CDObjectPool = null

## minimum time between shots in seconds
@export var cooldown: float = 0.3

## optional spawn context to apply to each projectile
@export var spawn_context: CDSpawnContext = null

## rotate projectile to match entity's facing direction
@export var inherit_rotation: bool = true

## max concurrent live projectiles (0 = unlimited)
@export var max_bullets: int = 0

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"shoot"]

## timestamp of last shot for cooldown enforcement
var _last_fire_time: float = -999.0

## currently live projectiles for max_bullets tracking
var _live_bullets: Array[CDEntity] = []

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect fire signals
func _on_initialize() -> void:
	for sig in fire_signals:
		entity.bus_connect(sig, _on_fire)

## spawn a projectile if cooldown and max bullet limits allow
func _on_fire() -> void:
	## enforce cooldown
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_fire_time < cooldown:
		return
	_last_fire_time = now

	_live_bullets = _live_bullets.filter(func(b): return is_instance_valid(b) and b.state != CDEnums.EntityState.INACTIVE)
	if max_bullets > 0 and _live_bullets.size() >= max_bullets:
		return

	if bullet_scene == null:
		return

	var projectile: CDEntity

	## acquire from pool or instantiate fresh
	if pool:
		projectile = pool.acquire()
		if projectile == null:
			return
		projectile.global_position = global_position
	else:
		projectile = bullet_scene.instantiate()
		projectile.global_position = global_position

	CDUtilities.apply_spawn_context(projectile, spawn_context)

	if inherit_rotation:
		projectile.rotation = global_rotation
		projectile.velocity = projectile.velocity.rotated(global_rotation)

	## activate pooled entity or add to scene tree
	if pool:
		projectile.activate()
	else:
		game.add_child(projectile)

	_live_bullets.append(projectile)
	projectile.connect("entity_deactivating", _on_bullet_gone.bind(projectile))

## clear bullet tracking and disconnect fire signals
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_live_bullets.clear()
	for sig in fire_signals:
		if entity.is_connected(sig, _on_fire):
			entity.disconnect(sig, _on_fire)

## remove a bullet from tracking when it deactivates
func _on_bullet_gone(bullet: CDEntity) -> void:
	_live_bullets.erase(bullet)
