## applies a physical impulse to ImpulseReceiverGuts on the target
class_name PushbackArm extends CDEntityComponent

@export var push_force: float = 500.0
@export var use_collision_normal: bool = true
@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var impulse_signals: Array[StringName] = [&"external_impulse"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

func _on_collision(collider: CDEntity, normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	
	var impulse_direction: Vector2
	if use_collision_normal:
		impulse_direction = normal
	else:
		impulse_direction = (collider.global_position - entity.global_position).normalized()
	
	var impulse = impulse_direction * push_force
	
	for sig in impulse_signals:
		if collider.has_signal(sig):
			collider.emit_signal(sig, impulse)

func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
