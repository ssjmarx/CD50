# Simple bullet. Flies straight, despawns on hit/screen exit, plays hit sound.

extends UniversalBody

@export var radius: float = 4.0 # Bullet size (square)

var is_alive: bool = true # Prevents multiple hit triggers

@onready var physicsbox = $CollisionShape2D # Physics collider
@onready var hitbox = $HitBox/CollisionShape2D # Gameplay detection
@onready var sound = $AudioStreamPlayer2D # Hit sound

# Set up collision shapes and signals
func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(radius, radius)
	
	$CollisionShape2D.shape = shape
	$HitBox/CollisionShape2D.shape = shape
	
	$HitBox.body_entered.connect(_on_hitbox_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

# Draw white square
func _draw() -> void:
	draw_rect(Rect2(-radius / 2.0, -radius / 2.0, radius, radius), Color.WHITE)

# Move and check for collision
func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	var collision = move_and_collide(velocity * delta)
	if collision:
		bullet_hit(collision.get_collider())

# Hitbox collision detected
func _on_hitbox_entered(target) -> void:
	if not is_alive:
		return
	bullet_hit(target.get_collider())

# Clean up when off-screen
func _on_screen_exited() -> void:
	if is_alive:
		queue_free()
	
# Handle bullet hit (disable colliders, play sound, despawn)
func bullet_hit(collider) -> void:
	if collider.has_node("Health"):
		collider.get_node("Health").reduce_health(1)

	is_alive = false
	
	hide()
	$CollisionShape2D.set_deferred("disabled", true)
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	
	sound.play()
	await sound.finished
	queue_free()
