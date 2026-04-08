extends Node

@export var target: NodePath
@export var turning_speed: float = 50.0

@onready var target_node = get_node(target)
@onready var parent_node = get_parent()

var tracked_position: Vector2
var current_position: Vector2
var target_output: Vector2
var actual_output: Vector2

func _ready() -> void:
	await get_tree().process_frame
	actual_output = (target_node.global_position - parent_node.global_position).normalized()

func _physics_process(delta: float) -> void:
	if target_node == null:
		return
	
	target_output =  target_node.global_position - parent_node.global_position
	actual_output = actual_output.slerp(target_output.normalized(), turning_speed * delta)
	parent_node.set_direct_movement(actual_output)
