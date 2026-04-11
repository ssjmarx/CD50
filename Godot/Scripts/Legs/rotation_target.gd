# rotation towards mouse or joystick input.  Speed is given in degrees per second.

extends Node

@export var turning_speed: int = 100

var target_rotation: float = 0.0
var target_position: Vector2

@onready var parent = get_parent()

func _ready() -> void:
	parent.move_to.connect(_on_move_to)

func _physics_process(delta: float) -> void:
	target_rotation = (target_position - parent.position).angle()
	parent.rotation = rotate_toward(parent.rotation, target_rotation, deg_to_rad(turning_speed) * delta)

func _on_move_to(mouse_pos: Vector2) -> void:
	target_position = mouse_pos
	target_rotation = (mouse_pos - parent.position).angle()
