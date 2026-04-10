# a classic arcade-style gun.  shoots rapidly, but limits the number of bullets on screen at a time.

extends Node

signal target_hit(target: Node2D)

@export var ammo: PackedScene
@export var max_bullets: int = 4
@export var muzzle_offset: int = 20
@export var initial_velocity: int = 800

var active_bullets: Array[CharacterBody2D]

@onready var parent = get_parent()

func _ready() -> void:
	parent.shoot.connect(_on_shoot)

func _on_shoot() -> void:
	active_bullets = active_bullets.filter(is_instance_valid)
	
	if active_bullets.size() >= max_bullets:
		return
	
	var bullet: CharacterBody2D = ammo.instantiate()
	
	parent.get_parent().add_child(bullet)
	bullet.BulletCollision.connect(_on_bullet_hit)
	active_bullets.push_back(bullet)
	
	bullet.velocity = Vector2.from_angle(parent.rotation) * initial_velocity
	bullet.global_position = parent.global_position + Vector2.from_angle(parent.rotation) * muzzle_offset

func _on_bullet_hit(target: Node2D) -> void:
	target_hit.emit(target)
