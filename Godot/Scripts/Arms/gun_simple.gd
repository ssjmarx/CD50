# Classic arcade-style gun. Limits active bullets to prevent spamming. Supports joystick and mouse aim.

extends Node

# Emitted when a bullet hits a target
signal target_hit(target: Node2D)

@export var ammo: PackedScene # Bullet scene to instantiate
@export var max_bullets: int = 4 # Maximum bullets on screen
@export var muzzle_offset: int = 20 # Distance from parent to spawn point
@export var initial_velocity: int = 800 # Bullet speed (pixels per second)
@export var joy_input: bool = false # Use joystick aiming
@export var mouse_input: bool = false # Use mouse aiming

var active_bullets: Array[CharacterBody2D] # Track spawned bullets
var aim_angle: float = 0.0 # Current aim direction
var has_aim_input: bool = false # Track if aim input received

@onready var parent = get_parent() # Reference to attached body
@onready var sound = $AudioStreamPlayer2D # Gun sound effect

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
	# Remove invalid bullets from tracking
	active_bullets = active_bullets.filter(is_instance_valid)
	
	# Don't shoot if at bullet limit
	if active_bullets.size() >= max_bullets:
		return
	
	# Use aim angle if provided, else face parent's rotation
	var firing_angle = aim_angle if has_aim_input else parent.rotation	
	var bullet: CharacterBody2D = ammo.instantiate()
	
	# Set bullet velocity and spawn position
	bullet.velocity = Vector2.from_angle(firing_angle) * initial_velocity
	bullet.global_position = parent.global_position + Vector2.from_angle(firing_angle) * muzzle_offset
	
	# Add bullet to scene and track it
	parent.get_parent().add_child(bullet)
	bullet.BulletCollision.connect(_on_bullet_hit)
	active_bullets.push_back(bullet)
	
	sound.play()

# Forward bullet hit signal
func _on_bullet_hit(target: Node2D) -> void:
	target_hit.emit(target)