# ai that looks forward and emits a shoot signal if it sees a target group in its vision cone

extends UniversalComponent

@export var target_group: String
@export var vision_cone_angle: float = 15
@export var vision_range: float = 500
@export var fire_rate: float = 2.0

@onready var timer: float = fire_rate

func _physics_process(delta):
	timer += delta
	
	if timer < fire_rate:
		return
	
	if _get_target_in_cone():
		parent.shoot.emit()
		timer = 0.0

func _get_target_in_cone() -> Node2D:
	var target_nodes = get_tree().get_nodes_in_group(target_group)
	
	for node in target_nodes:
		if not is_instance_valid(node):
			return null
		else:
			var angle_diff = angle_difference(parent.rotation, parent.global_position.angle_to_point(node.global_position))
			if abs(angle_diff) <= deg_to_rad(vision_cone_angle / 2.0):
				var dist = parent.global_position.distance_squared_to(node.global_position)
				if vision_range <= 0 or dist <= vision_range * vision_range:
					return node
	
	return null
