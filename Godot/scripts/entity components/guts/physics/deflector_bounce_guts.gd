## DeflectorBounceGuts
## Collision handler that deflects off target groups with angled bounce physics
## Owns its own deflection config — no arm component needed

class_name DeflectorBounceGuts extends CDEntityComponent

## --- exports ---

## groups to handle collisions for; empty = handle all (trust the collision matrix)
@export var target_groups: Array[StringName] = []
## per-axis bounce bias (1,1 = neutral; higher = stronger deflection on that axis)
@export var deflection_bias: Vector2 = Vector2(1, 1)
## velocity multiplier on bounce (1.0 = no energy loss)
@export var restitution: float = 1.0

## --- lifecycle ---

## set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

## register as a collision handler on the entity
func _on_initialize() -> void:
	entity.register_collision_handler(target_groups, _handle_collision)

## --- collision handling ---

## compute deflected velocity based on offset from collider, apply bias and restitution
func _handle_collision(collision: KinematicCollision2D) -> Vector2:
	var collider = collision.get_collider()
	var normal = collision.get_normal()
	
	## calculate deflection direction from relative positions
	var raw_offset = (entity.global_position - collider.global_position).normalized()
	raw_offset.x *= deflection_bias.x
	raw_offset.y *= deflection_bias.y
	raw_offset = raw_offset.normalized()
	
	var speed = entity.velocity.length() * restitution
	entity.velocity = raw_offset * speed
	
	return collision.get_remainder().slide(normal)

## --- cleanup ---

## unregister collision handler for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.unregister_collision_handler(_handle_collision)
