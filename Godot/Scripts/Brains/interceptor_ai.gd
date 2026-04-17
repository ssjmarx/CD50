# AI brain that steers toward target node with adjustable turning speed and inaccuracy.

extends UniversalComponent

@export var target_group: String
@export var turning_speed: int = 45
@export var aim_inaccuracy: int = 0

var current_aim_angle: float = 0.0
var _initialized: bool = false

# Steer toward target with turning speed limit and random noise
func _physics_process(delta: float) -> void:
	var nodes = get_tree().get_nodes_in_group(target_group)
	var closest_node = null
	var closest_dist = INF

	for node in nodes:
		if not is_instance_valid(node):
			continue
		var dist = parent.global_position.distance_squared_to(node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node
		
	if closest_node == null:
		parent.left_joystick.emit(Vector2.ZERO)
		return
	
	if not _initialized:
		current_aim_angle = (closest_node.global_position - parent.global_position).angle()
		_initialized = true
	
	var target_angle = (closest_node.global_position - parent.global_position).angle()
	var noise = deg_to_rad(randf_range(-aim_inaccuracy, aim_inaccuracy))
	
	current_aim_angle = rotate_toward(current_aim_angle, target_angle + noise, deg_to_rad(turning_speed) * delta)

	parent.left_joystick.emit(Vector2.from_angle(current_aim_angle))

# Change target at runtime
func set_target_group(group: String) -> void:
	target_group = group
