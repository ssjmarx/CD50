extends Node

@export var target_node: NodePath
@export var turning_speed: float = 50.0

var tracked_position: Vector2
var current_position: Vector2
var target_output: Vector2
var actual_output: Vector2

@onready var target = get_node(target_node)
@onready var parent = get_parent()

func _ready() -> void:
	await get_tree().process_frame
	actual_output = (target.global_position - parent.global_position).normalized()

func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	target_output =  target.global_position - parent.global_position
	actual_output = actual_output.slerp(target_output.normalized(), turning_speed * delta)
	parent.left_joystick.emit(actual_output)
	
	# print("target_output: ", target_output, " actual_output: ", actual_output)
