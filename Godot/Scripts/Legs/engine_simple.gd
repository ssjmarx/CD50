# simple engine for Asteroids-like movement.  top speed 0 enables infinite speed, friction 0 prevents stoppage.  high friction can prevent movement.

extends Node

@export var acceleration: int = 225
@export var top_speed: int = 300
@export var button_only: bool = true

var thrusting: bool = false
var joystick_input: bool = false

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)

func _on_move(joystick: Vector2) -> void:
	if button_only == true:
		return
	if joystick == Vector2.ZERO:
		joystick_input = false
	else:
		joystick_input = true

func _physics_process(delta):
	var forward = Vector2.from_angle(parent.rotation)
	if thrusting or joystick_input:
		parent.velocity += forward * acceleration * delta
	if top_speed > 0:
		parent.velocity = parent.velocity.limit_length(top_speed)

func _on_thrust() -> void:
	thrusting = true

func _on_end_thrust() -> void:
	thrusting = false
