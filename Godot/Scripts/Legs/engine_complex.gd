# movement component that uses acceleration and friction.  Speeds are in pixels per second (per second (per second)).  When friction and max_acceleration are equal, top speed is your actual top speed.  Higher friction gives a lower actual top speed, higher acceleration gives a higher actual top speed.  Zero friction gives Newtonian movement.

extends Node

@export var max_acceleration: int = 200
@export var jerk: int = 300
@export var button_only: bool = true

var current_acceleration: float = 0.0
var thrusting: bool = false
var joystick_input: bool = false

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)
	parent.thrust.connect(_on_thrust)
	parent.end_thrust.connect(_on_end_thrust)

func _physics_process(delta):
	if thrusting or joystick_input:
		current_acceleration = min(current_acceleration + jerk * delta, max_acceleration)
	else:
		current_acceleration = maxf(current_acceleration - jerk * delta, 0.0)
	
	var forward = Vector2.from_angle(parent.rotation)
	if thrusting or joystick_input:
		parent.velocity += forward * current_acceleration * delta

func _on_move(joystick: Vector2) -> void:
	if button_only == true:
		return
	if joystick == Vector2.ZERO:
		joystick_input = false
	else:
		joystick_input = true

func _on_thrust() -> void:
	thrusting = true

func _on_end_thrust() -> void:
	thrusting = false
