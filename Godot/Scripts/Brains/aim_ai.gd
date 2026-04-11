extends Node

@export var target_node: NodePath
@export var turning_speed: int = 90
@export var aim_inaccuracy: int = 45

var current_aim_angle: float = 0.0

@onready var target = get_node(target_node)
@onready var parent = get_parent()

func _ready() -> void:
	await get_tree().process_frame
	if is_instance_valid(target):
		current_aim_angle = (target.global_position - parent.global_position).angle()

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
		
	var target_angle = (target.global_position - parent.global_position).angle()
	var noise = deg_to_rad(randf_range(-aim_inaccuracy, aim_inaccuracy))
	
	current_aim_angle = rotate_toward(current_aim_angle, target_angle + noise, deg_to_rad(turning_speed) * delta)

	parent.right_joystick.emit(Vector2.from_angle(current_aim_angle))
