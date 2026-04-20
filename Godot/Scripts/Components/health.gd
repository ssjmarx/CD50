# Health component. Tracks HP, emits signals on change, and handles death by disabling colliders and freeing the parent.

extends UniversalComponent

signal health_changed(current_health: int, parent: Node)
signal zero_health(parent: Node)

# Health configuration
@export var max_health: int = 1
@export var death_sound: AudioStream

@onready var current_health: int = max_health

# Reduce HP and emit signals; triggers death if health reaches zero
func reduce_health(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		zero_health.emit(parent)
		die()

# Hide parent, zero velocity, disable all colliders and child processing, then free
func die() -> void:
	parent.hide()
	
	if "velocity" in parent:
		parent.velocity = Vector2.ZERO
	
	# Disable all collision shapes (direct children and inside Area2D children)
	for child: Node in parent.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			for shape: Node in child.get_children():
				if shape is CollisionShape2D or shape is CollisionPolygon2D:
					shape.set_deferred("disabled", true)
	
	# Disable processing on all siblings
	for child: Node in parent.get_children():
		if child != self: 
			child.process_mode = Node.PROCESS_MODE_DISABLED
	
	parent.queue_free()