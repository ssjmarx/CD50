# rotation towards mouse or joystick input.  Speed is given in degrees per second.

extends Node

@export var turning_speed: int = 240
@export var enable_mouse: bool = true

var target_rotation: float = 0.0
var target_position: Vector2
var has_target: bool = false

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)
	parent.move_to.connect(_on_move_to)

func _physics_process(delta: float) -> void:
	if has_target:
		target_rotation = (target_position - parent.position).angle()
	parent.rotation = rotate_toward(parent.rotation, target_rotation, deg_to_rad(turning_speed) * delta)

func _on_move(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		target_rotation = direction.angle()
		has_target = false

func _on_move_to(mouse_pos: Vector2) -> void:
	if enable_mouse:
		target_position = mouse_pos
		target_rotation = (mouse_pos - parent.position).angle()
		has_target = true
