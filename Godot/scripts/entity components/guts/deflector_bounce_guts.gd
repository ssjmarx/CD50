## collision handler that deflects off target groups with angled bounce physics
## owns its own deflection config — no arm needed
class_name DeflectorBounceGuts extends CDEntityComponent

@export var target_groups: Array[StringName] = []  # empty = handle all collisions (trust the matrix)
@export var deflection_bias: Vector2 = Vector2(1, 1)
@export var restitution: float = 1.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	entity.register_collision_handler(target_groups, _handle_collision)

func _handle_collision(collision: KinematicCollision2D) -> Vector2:
	var collider = collision.get_collider()
	var normal = collision.get_normal()
	
	var raw_offset = (entity.global_position - collider.global_position).normalized()
	raw_offset.x *= deflection_bias.x
	raw_offset.y *= deflection_bias.y
	raw_offset = raw_offset.normalized()
	
	var speed = entity.velocity.length() * restitution
	entity.velocity = raw_offset * speed
	
	# slide remainder along collision normal (stay at surface)
	return collision.get_remainder().slide(normal)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.unregister_collision_handler(_handle_collision)