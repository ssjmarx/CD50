# most basic type of bullet.  flies straight, cleans itself up, plays a sound when it hits something, needs to be told how fast to fly.  wraps around the screen.

extends CharacterBody2D

signal BulletCollision

@export var radius: float = 4.0

var is_alive: bool = true

@onready var physicsbox = $CollisionShape2D
@onready var hitbox = $hitbox/CollisionShape2D
@onready var sound = $AudioStreamPlayer2D

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$hitbox/CollisionShape2D.shape = shape
	
	$hitbox.body_entered.connect(_on_hitbox_entered)
	$Timer.timeout.connect(_on_timeout)

func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	var collision = move_and_collide(velocity * delta)
	if collision:
		bullet_hit(collision.get_collider())

func _on_hitbox_entered(target: Node2D) -> void:
	if not is_alive:
		return
	bullet_hit(target)

func _on_timeout() -> void:
	if is_alive:
		queue_free()

func bullet_hit(target) -> void:
	is_alive = false
	BulletCollision.emit(target)
	
	hide()
	$CollisionShape2D.set_deferred("disabled", true)
	$hitbox/CollisionShape2D.set_deferred("disabled", true)
	
	sound.play()
	await sound.finished
	queue_free()
