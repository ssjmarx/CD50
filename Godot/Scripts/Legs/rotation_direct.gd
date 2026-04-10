# tank-style rotation in an input direction.  Speed is given in degrees per second.

extends Node

@export var turning_speed: int = 240

var turning_left: bool = false
var turning_right: bool = false

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)

func _physics_process(delta: float) -> void:
	if turning_right:
		parent.rotation += deg_to_rad(turning_speed) * delta
	if turning_left:
		parent.rotation -= deg_to_rad(turning_speed) * delta

func _on_move(direction: Vector2) -> void:
	if direction.x > 0:
		turning_right = true
		turning_left = false
	elif direction.x < 0:
		turning_left = true
		turning_right = false
	else:
		turning_left = false
		turning_right = false
