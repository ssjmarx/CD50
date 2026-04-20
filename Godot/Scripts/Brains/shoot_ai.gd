# AI brain that fires when a target from the specified group enters its vision cone.

extends UniversalComponent

# Vision and firing configuration
@export var target_group: String
@export var vision_cone_angle: float = 15
@export var vision_range: float = 500
@export var fire_rate: float = 2.0

@onready var timer: float = fire_rate

# Accumulate time and fire when a target is within the vision cone
func _physics_process(delta: float) -> void:
	timer += delta
	
	if timer < fire_rate:
		return
	
	if _get_target_in_cone():
		parent.shoot.emit()
		timer = 0.0

# Check if any target in the group is within the angular cone and range
func _get_target_in_cone() -> Node2D:
	var target_nodes: Array[Node] = get_tree().get_nodes_in_group(target_group)
	
	for node: Node in target_nodes:
		if not is_instance_valid(node):
			return null
		else:
			var angle_diff: float = angle_difference(parent.rotation, parent.global_position.angle_to_point(node.global_position))
			if abs(angle_diff) <= deg_to_rad(vision_cone_angle / 2.0):
				var dist: float = parent.global_position.distance_squared_to(node.global_position)
				if vision_range <= 0 or dist <= vision_range * vision_range:
					return node
	
	return null