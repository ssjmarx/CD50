extends CharacterBody2D

@export var paddle_width: int = 4
@export var paddle_height: int = 16
@export var paddle_speed: int = 600
@export var paddle_x_min: float = 0.0
@export var paddle_x_max: float = 640.0
@export var paddle_y_min: float = 0.0
@export var paddle_y_max: float = 360.0
@export var lock_x: bool = false
@export var lock_y: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var target: Vector2 = Vector2.ZERO
var input: Vector2 = Vector2.ZERO
var has_target: bool = false

func _draw() -> void:
	draw_rect(Rect2(-paddle_width / 2.0, -paddle_height / 2.0, paddle_width, paddle_height), Color.WHITE)

func _ready() -> void:
	collision_shape.shape.size = Vector2(paddle_width, paddle_height)

func _physics_process(delta: float) -> void:
	if has_target:
		if lock_x:
			target.x = position.x
		if lock_y:
			target.y = position.y
		position = position.move_toward(target, paddle_speed * delta)
	else:
		if lock_x:
			input.x = 0
		if lock_y:
			input.y = 0
		position += input * paddle_speed * delta
	
	position.x = clampf(position.x, paddle_x_min + paddle_width / 2.0, paddle_x_max - paddle_width / 2.0)
	position.y = clampf(position.y, paddle_y_min + paddle_height / 2.0, paddle_y_max - paddle_height / 2.0)

func set_target_coords(coords: Vector2) -> void:
	has_target = true
	target = coords

func set_direct_movement(direct: Vector2) -> void:
	has_target = false
	input = direct.limit_length(1.0)
	
func bounce_offset(collision_location: Vector2) -> Vector2:
	return (collision_location - self.global_position).normalized()
