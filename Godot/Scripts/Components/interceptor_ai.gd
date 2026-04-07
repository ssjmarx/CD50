extends Node

@export var target: NodePath
@export var lag: float = 0.2
@export var dead_zone: int = 16
@export var ramp_distance: int = 32

@onready var target_node = get_node(target)

var timer = 0.0
var tracked_position: Vector2
var current_position: Vector2

func _physics_process(delta: float) -> void:
	if target_node == null:
		return
	
	timer += delta
	if timer >= lag:
		tracked_position = target_node.global_position
		current_position = get_parent().global_position
		timer = 0.0
	
	var output = tracked_position - current_position
	
	if output.length() > dead_zone:
		get_parent().set_direct_movement(output.limit_length(ramp_distance) / ramp_distance)
	else:
		get_parent().set_direct_movement(Vector2.ZERO)
