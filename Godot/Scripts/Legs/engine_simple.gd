# simple engine for Asteroids-like movement.  top speed 0 enables infinite speed, friction 0 prevents stoppage.  high friction can prevent movement.

extends Node

@export var acceleration: int = 400
@export var top_speed: int = 400
@export var friction: int = 40

var velocity: Vector2 = Vector2.ZERO
var thrusting: bool = false

@onready var parent = get_parent()

var input: Vector2 = Vector2.ZERO

func _ready() -> void:
	parent.move.connect(_on_move)

func _on_move(direction: Vector2) -> void:
	input = direction

func _physics_process(delta: float) -> void:
	if input.length() > 0.0:
		var forward = Vector2.from_angle(parent.rotation)
		velocity += forward * acceleration * delta
		if top_speed > 0:
			velocity = velocity.limit_length(top_speed)
	
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	parent.position += velocity * delta
	
	# print("velocity: ", velocity)

func _thruster_on() -> void:
	thrusting = true
	# print("thruster on")

func _thruster_off() -> void:
	thrusting = false
	# print("thruster off")
