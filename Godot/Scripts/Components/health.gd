extends Node

signal health_changed(current_health: int, parent: Node)
signal zero_health(parent: Node)

@export var max_health = 1
@export var death_sound: AudioStream

@onready var parent = get_parent()
@onready var current_health = max_health

func reduce_health(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		zero_health.emit(parent)
		die()

func die() -> void:
	parent.hide()
	
	if "velocity" in parent:
		parent.velocity = Vector2.ZERO
	
	for child in parent.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			for shape in child.get_children():
				if shape is CollisionShape2D or shape is CollisionPolygon2D:
					shape.set_deferred("disabled", true)
	
	if death_sound:
		var player = AudioStreamPlayer2D.new()
		parent.add_child(player)
		player.stream = death_sound
		player.play()
		await player.finished
		player.queue_free()
	
	parent.queue_free()
