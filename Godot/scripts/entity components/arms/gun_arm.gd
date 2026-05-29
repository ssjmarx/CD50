## spawns a projectile on a fire signal
class_name GunArm extends CDEntityComponent

@export var bullet_scene: PackedScene
@export var pool: CDObjectPool = null
@export var cooldown: float = 0.3
@export var spawn_context: CDSpawnContext = null
@export var inherit_rotation: bool = true
@export var max_bullets: int = 0

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"shoot"]

var _last_fire_time: float = -999.0
var _live_bullets: Array[CDEntity] = []

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in fire_signals:
		entity.ensure_signal(sig) 
		entity.connect(sig, _on_fire)

func _on_fire() -> void:
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

	if pool:
		projectile.activate()
	else:
		game.add_child(projectile)
	
	# track the live bullet
	_live_bullets.append(projectile)
	projectile.connect("entity_deactivating", _on_bullet_gone.bind(projectile))

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_live_bullets.clear()
	for sig in fire_signals:
		if entity.is_connected(sig, _on_fire):
			entity.disconnect(sig, _on_fire)

func _on_bullet_gone(bullet: CDEntity) -> void:
	_live_bullets.erase(bullet)
