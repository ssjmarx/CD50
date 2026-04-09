# movement component that uses acceleration and friction.  Speeds are in pixels per second (per second (per second)).  If friction is below max acceleration, you will be able to accelerate infinitely.  If there is zero friction, you will have Newtonian motion and top speed won't matter.  If friction is above max acceleration, you won't ever reach top speed.

extends Node

@export var top_speed: int = 400
@export var friction: int = 400
@export var max_acceleration: int = 400
@export var jerk: int = 400

var input: float
var velocity: Vector2 = Vector2.ZERO
var current_acceleration: float = 0.0

@onready var parent = get_parent()

func _ready() -> void:
	parent.move.connect(_on_move)

func _physics_process(delta: float) -> void:
	if input != 0.0:
		current_acceleration = min((current_acceleration + (jerk * input * delta)), max_acceleration)
	else:
		current_acceleration = maxf(current_acceleration - jerk * delta, 0.0)
	
	var forward = Vector2.from_angle(parent.rotation)
	velocity += forward * current_acceleration * delta
	
	if top_speed > 0:
		var resistance = friction * (velocity / top_speed)
		velocity -= resistance * delta
	
	parent.position += velocity * delta
	
	# print("velocity ", velocity)

func _on_move(joystick: Vector2) -> void:
	input = joystick.length()
