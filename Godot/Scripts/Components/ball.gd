extends CharacterBody2D

signal BallCollision

@export var initial_velocity: Vector2 = Vector2(0, 0)
@export var acceleration_factor: float = 1.2
@export var acceleration_levels: int = 8
@export var radius: float = 1.0

@onready var sound = $AudioStreamPlayer2D

var sound1 = preload("res://Assets/Audio/tone1.ogg")
var sound2 = preload("res://Assets/Audio/twoTone1.ogg")
var sound3 = preload("res://Assets/Audio/twoTone2.ogg")

var current_acceleration_level: int = 1

func _ready() -> void:
	$CollisionShape2D.shape.size = Vector2(radius, radius)
	velocity = initial_velocity

func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		emit_signal("BallCollision", collision.get_collider())
		sound.play()

func accelerate() -> void:
	if current_acceleration_level < acceleration_levels:
		velocity = velocity * acceleration_factor
		current_acceleration_level += 1
	
	match current_acceleration_level:
		1, 2, 3, 4:
			sound.stream = sound1
		5, 6:
			sound.stream = sound2
		7, 8:
			sound.stream = sound3

func reset() -> void:
	current_acceleration_level = 1
	sound.stream = sound1
	
func custom_bounce(angle: Vector2) -> void:
	var speed = velocity.length()
	velocity = angle * speed
