# movement component that rotates towards the mouse or the input diretion.  turning speed is percentage of slerp.

# simple_rotation.gd
extends Node

@export var turning_speed: float = 10.0

var target_rotation: float = 0.0
var target_position: Vector2
var has_target: bool = false

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)
	parent.move_to.connect(_on_move_to)

func _on_move(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		target_rotation = direction.angle()
		has_target = false

func _on_move_to(mouse_pos: Vector2) -> void:
	target_position = mouse_pos
	target_rotation = (mouse_pos - parent.position).angle()
	has_target = true

func _physics_process(delta: float) -> void:
	if has_target:
		target_rotation = (target_position - parent.position).angle()
	parent.rotation = lerp_angle(parent.rotation, target_rotation, min(turning_speed * delta, 1.0))
