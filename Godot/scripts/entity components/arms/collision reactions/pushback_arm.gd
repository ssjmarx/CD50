# PushbackArm
# Applies a physical impulse to the collider on collision
# Emits external_impulse on the collider, using collision normal or direction vector

class_name PushbackArm extends CDEntityComponent

# magnitude of the pushback impulse
@export var push_force: float = 500.0

# true = use collision normal, false = use direction from self to collider
@export var use_collision_normal: bool = true

# if non-empty, only push colliders in these groups
@export var target_groups: Array[StringName]


@export_group("Blackboard Keys")
@export var impulse_keys: Array[StringName] = [&"external_impulse"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var impulse_signals: Array[StringName] = [&"external_impulse"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect collision signals
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)

# calculate impulse direction and emit on the collider
func _on_collision(collider: CDEntity, normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	# determine impulse direction
	var impulse_direction: Vector2
	if use_collision_normal:
		impulse_direction = normal
	else:
		impulse_direction = (collider.global_position - entity.global_position).normalized()

	var impulse = impulse_direction * push_force

	# write to blackboard
	for key in impulse_keys:
		collider.blackboard[key] = impulse

	# emit impulse signal on the collider
	for sig in impulse_signals:
		collider.bus_emit(sig)

# return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

# disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
