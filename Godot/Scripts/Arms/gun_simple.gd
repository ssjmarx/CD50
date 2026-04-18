# Classic arcade-style gun. Limits active bullets to prevent spamming. Supports joystick and mouse aim.

extends UniversalComponent

# Emitted when a bullet hits a target
signal target_hit(target: Node2D)

@export var ammo: PackedScene 
@export var max_bullets: int = 4
@export var muzzle_offset: int = 20
@export var initial_velocity: int = 800
@export var joy_input: bool = false
@export var mouse_input: bool = false
@export var bullet_group: String = ""

var active_bullets: Array[CharacterBody2D]
var aim_angle: float = 0.0
var has_aim_input: bool = false

@onready var sound = $AudioStreamPlayer2D

# Connect to input signals
func _ready() -> void:
	parent.shoot.connect(_on_shoot)
	parent.aim.connect(_on_aim)
	parent.aim_at.connect(_on_aim_at)

# Store joystick aim direction
func _on_aim(direction: Vector2) -> void:
	if joy_input:
		if direction != Vector2.ZERO:
			aim_angle = direction.angle()
			has_aim_input = true

# Store mouse aim direction
func _on_aim_at(target_pos: Vector2) -> void:
	if mouse_input:
		aim_angle = (target_pos - parent.global_position).angle()
		has_aim_input = true

# Spawn bullet if under limit
func _on_shoot() -> void:
	active_bullets = active_bullets.filter(is_instance_valid)
	
	if active_bullets.size() >= max_bullets:
		return
	
	var firing_angle = aim_angle if has_aim_input else parent.rotation	
	var bullet: CharacterBody2D = ammo.instantiate()
	
	bullet.velocity = Vector2.from_angle(firing_angle) * initial_velocity
	bullet.global_position = parent.global_position + Vector2.from_angle(firing_angle) * muzzle_offset
	if bullet_group != "":
		bullet.collision_groups.append(bullet_group)
	
	parent.get_parent().add_child(bullet)
	active_bullets.push_back(bullet)
	
	sound.play()

# Forward bullet hit signal
func _on_bullet_hit(target: Node2D) -> void:
	target_hit.emit(target)
