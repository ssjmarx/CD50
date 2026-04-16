# Pong-style ball. Bounces off colliders and plays sounds on impact.

extends "res://Scripts/Core/universal_body.gd"

@export var initial_velocity: Vector2 = Vector2(0, 0) # Starting velocity
@export var radius: float = 4.0 # Ball size (square)

# Audio samples for different speed levels
var sound1 = preload("res://Assets/Audio/tone1.ogg")
var sound2 = preload("res://Assets/Audio/twoTone1.ogg")
var sound3 = preload("res://Assets/Audio/twoTone2.ogg")

@onready var sound = $AudioStreamPlayer2D # Collision sound
@onready var accelerator = $PongAcceleration # Speed boost component
@onready var physicsbox = $CollisionShape2D # Physics collider
@onready var hitbox = $HitBox # Gameplay detection area

# Set up collision shapes
func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$HitBox/CollisionShape2D.shape = shape

# Draw white square
func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)

# Move and play sound on collision
func _physics_process(delta: float) -> void:
	var collision = move_parent_physics(velocity * delta)
	
	if collision:
		sound.play()

# Bounce in custom direction, preserving speed
func custom_bounce(angle: Vector2) -> void:
	var speed = velocity.length()
	velocity = angle * speed

# Change sound based on speed level
func _on_pong_acceleration_speed_changed(speed_level: Variant) -> void:
	match speed_level:
		1, 2, 3:
			sound.stream = sound1
		4, 5, 6:
			sound.stream = sound2
		7, 8:
			sound.stream = sound3

# Increase ball speed
func accelerate() -> void:
	accelerator.accelerate()

# Reset speed to level 1
func reset() -> void:
	accelerator.reset()
