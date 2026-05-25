## rotates toward an aim direction
class_name TargetRotationLeg extends CDEntityComponent

@export var rotation_speed: float = 360.0 # 0 = instant snap

@export_group("Listen Signals")
@export var aim_signals: Array[StringName] = [&"aim"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in aim_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_aim)

func _on_aim(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var target_angle := direction.angle()
	var current := entity.global_rotation
	var angle_diff := angle_difference(current, target_angle)
	
	if rotation_speed <= 0.0:
		entity.request_rotation_set(target_angle)
	else:
		var max_step := deg_to_rad(rotation_speed) * get_physics_process_delta_time()
		if absf(angle_diff) <= max_step:
			entity.request_rotation_set(target_angle)  # snap to prevent overshoot
		else:
			entity.request_rotation_set(current + signf(angle_diff) * max_step)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in aim_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_aim):
			entity.disconnect(sig, _on_aim)
