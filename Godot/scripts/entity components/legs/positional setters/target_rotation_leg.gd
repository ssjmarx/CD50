# TargetRotationLeg
# Rotates entity to face the move_direction vector polled from the entity blackboard
# Supports instant snap (rotation_speed <= 0) and smooth rotation with overshoot prevention

class_name TargetRotationLeg extends CDEntityComponent

# --- exports ---

# rotation speed in degrees per second (0 or below = instant snap)
@export var rotation_speed: float = 360.0

@export_group("Blackboard Keys")
# key to read move direction from (Vector2 — rotates to face this direction)
@export var direction_key: StringName = &"move_direction"

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	pass

# --- processing ---

# poll move_direction, rotate to face it
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	if direction == Vector2.ZERO:
		return
	
	var target_angle := direction.angle()
	var current := entity.global_rotation
	var angle_diff := angle_difference(current, target_angle)
	
	# instant snap mode
	if rotation_speed <= 0.0:
		entity.request_rotation_set(target_angle)
	else:
		# smooth rotation with overshoot prevention
		var max_step := deg_to_rad(rotation_speed) * get_physics_process_delta_time()
		if absf(angle_diff) <= max_step:
			entity.request_rotation_set(target_angle)
		else:
			entity.request_rotation_set(current + signf(angle_diff) * max_step)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()