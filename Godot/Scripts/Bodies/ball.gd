# Pong-style ball.  Takes the form of a square.

extends CharacterBody2D

signal BallCollision

@export var initial_velocity: Vector2 = Vector2(0, 0)
@export var radius: float = 4.0

var sound1 = preload("res://Assets/Audio/tone1.ogg")
var sound2 = preload("res://Assets/Audio/twoTone1.ogg")
var sound3 = preload("res://Assets/Audio/twoTone2.ogg")

@onready var sound = $AudioStreamPlayer2D
@onready var accelerator = $PongAcceleration
@onready var physicsbox = $CollisionShape2D
@onready var hitbox = $hitbox

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$hitbox/CollisionShape2D.shape = shape

func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		emit_signal("BallCollision", collision.get_collider())
		sound.play()

func custom_bounce(angle: Vector2) -> void:
	var speed = velocity.length()
	velocity = angle * speed

func _on_pong_acceleration_speed_changed(speed_level: Variant) -> void:
	match speed_level:
		1, 2, 3:
			sound.stream = sound1
		4, 5, 6:
			sound.stream = sound2
		7, 8:
			sound.stream = sound3

func accelerate() -> void:
	accelerator.accelerate()

func reset() -> void:
	accelerator.reset()
