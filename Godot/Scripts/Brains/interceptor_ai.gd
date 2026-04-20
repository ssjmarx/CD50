# AI brain that steers toward the closest target in a group. Emits to left_joystick for movement, not rotation.

extends UniversalComponent

# Targeting configuration
@export var target_group: String
@export var turning_speed: int = 45
@export var aim_inaccuracy: int = 0

# Runtime state
var current_aim_angle: float = 0.0
var _initialized: bool = false

# Find the closest valid target and smoothly steer toward it with noise
func _physics_process(delta: float) -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(target_group)
	var closest_node: Node = null
	var closest_dist: float = INF

	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = parent.global_position.distance_squared_to(node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node
		
	if closest_node == null:
		parent.left_joystick.emit(Vector2.ZERO)
		return
	
	if not _initialized:
		current_aim_angle = (closest_node.global_position - parent.global_position).angle()
		_initialized = true
	
	var target_angle: float = (closest_node.global_position - parent.global_position).angle()
	var noise: float = deg_to_rad(randf_range(-aim_inaccuracy, aim_inaccuracy))
	
	current_aim_angle = rotate_toward(current_aim_angle, target_angle + noise, deg_to_rad(turning_speed) * delta)
	parent.left_joystick.emit(Vector2.from_angle(current_aim_angle))

# Change the target group at runtime
func set_target_group(group: String) -> void:
	target_group = group