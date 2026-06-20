## LassoArm
## Spawns the lasso bullet payload when fired.
## Reads the firing entity and passes it to the bullet so the bullet knows who to report back to.

class_name LassoArm extends CDEntityComponent

@export var bullet_pool: CDObjectPool
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var initial_speed: float = 600.0

@export_group("Blackboard Keys")
@export var captor_key: StringName = &"captor"

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"fire_tractor_beam"]

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect fire signals
func _on_initialize() -> void:
	for sig in fire_signals:
		entity.bus_connect(sig, _on_fire)

## spawn bullet and initialize capture payload
func _on_fire() -> void:
	if not bullet_pool:
		push_warning("LassoArm has no bullet_pool assigned!")
		return

	var bullet = bullet_pool.acquire()
	# Assuming standard CD50 game structure where entities are added to the game root
	game.add_child(bullet)
	
	bullet.global_position = entity.global_position + spawn_offset
	
	# Fire bullet downwards (classic Galaga style)
	var direction = Vector2.DOWN 
	bullet.velocity = direction * initial_speed
	
	# Write captor reference to bullet
	bullet.blackboard[captor_key] = entity
	
	bullet.activate()

## disconnect fire signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in fire_signals:
		if entity.is_connected(sig, _on_fire):
			entity.disconnect(sig, _on_fire)
