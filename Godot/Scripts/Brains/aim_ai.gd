# AI brain that aims at target. Used for rotation, not movement (emits to right_joystick).

extends Node

@export var target_node: NodePath # Path to target entity
@export var turning_speed: int = 90 # Degrees per second to rotate
@export var aim_inaccuracy: int = 45 # Random aim error in degrees

var current_aim_angle: float = 0.0 # Current facing direction

@onready var target = get_node(target_node) # Target entity reference
@onready var parent = get_parent() # Reference to attached body

# Rotate toward target with turning speed limit and random noise
func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var target_angle = (target.global_position - parent.global_position).angle()
	var noise = deg_to_rad(randf_range(-aim_inaccuracy, aim_inaccuracy))
	
	current_aim_angle = rotate_toward(current_aim_angle, target_angle + noise, deg_to_rad(turning_speed) * delta)

	parent.right_joystick.emit(Vector2.from_angle(current_aim_angle))

# Change target at runtime
func set_target_node(node: Node) -> void:
	target = node
