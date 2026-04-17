# Health component. Tracks HP, emits signals on change, handles death (disable colliders, play sound, despawn).

extends UniversalComponent

# Emitted when health changes (passes current value and parent reference)
signal health_changed(current_health: int, parent: Node)
# Emitted when health reaches zero (passes parent reference)
signal zero_health(parent: Node)

@export var max_health = 1 # Starting health value
@export var death_sound: AudioStream # Sound to play on death

@onready var current_health = max_health # Current HP

# Reduce health and check for death
func reduce_health(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		zero_health.emit(parent)
		die()

# Disable entity, play death sound, and despawn
func die() -> void:
	parent.hide()
	
	# Stop physics movement
	if "velocity" in parent:
		parent.velocity = Vector2.ZERO
	
	# Disable all collision shapes
	for child in parent.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			for shape in child.get_children():
				if shape is CollisionShape2D or shape is CollisionPolygon2D:
					shape.set_deferred("disabled", true)
	
	# Disable all child components except this Health component
	for child in parent.get_children():
		if child != self: 
			child.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Play death sound if configured
	if death_sound:
		var player = AudioStreamPlayer2D.new()
		parent.add_child(player)
		player.stream = death_sound
		player.play()
		await player.finished
		player.queue_free()
	
	# Remove entity from scene
	parent.queue_free()
