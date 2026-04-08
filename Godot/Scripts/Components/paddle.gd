extends CharacterBody2D

@export var width: int = 4
@export var height: int = 16
@export var speed: int = 600
@export var x_min: float = 0.0
@export var x_max: float = 640.0
@export var y_min: float = 0.0
@export var y_max: float = 360.0
@export var lock_x: bool = false
@export var lock_y: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var deflector = $AngledDeflector

var target: Vector2 = Vector2.ZERO
var input: Vector2 = Vector2.ZERO
var has_target: bool = false

func _draw() -> void:
	draw_rect(Rect2(-width / 2.0, -height / 2.0, width, height), Color.WHITE)

func _ready() -> void:
	collision_shape.shape.size = Vector2(width, height)

func _physics_process(delta: float) -> void:
	if has_target:
		if lock_x:
			target.x = position.x
		if lock_y:
			target.y = position.y
		position = position.move_toward(target, speed * delta)
	else:
		if lock_x:
			input.x = 0
		if lock_y:
			input.y = 0
		position += input * speed * delta
	
	position.x = clampf(position.x, x_min + width / 2.0, x_max - width / 2.0)
	position.y = clampf(position.y, y_min + height / 2.0, y_max - height / 2.0)
	
	# print("input: ", input, " has_target: ", has_target)


func set_target_coords(coords: Vector2) -> void:
	has_target = true
	target = coords

func set_direct_movement(direct: Vector2) -> void:
	has_target = false
	input = direct.limit_length(1.0)

func bounce_offset(ball_position: Vector2) -> Vector2:
	return deflector.bounce_offset(ball_position)
