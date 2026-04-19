extends UniversalComponent

@export var chance_of_death: float = 0.25
@export var warp_duration: float = 0.5

func _ready() -> void:
	parent.action.connect(_on_action)

func _on_action(button: InputEvent) -> void:
	if button.is_action("button_1"):
		_do_warp()

func _do_warp() -> void:
	set_process(false)
	parent.velocity = Vector2.ZERO
	
	_set_collisions(false)
	parent.hide()
	
	parent.global_position = _random_position()
	parent.rotation = randf() * TAU
	
	await get_tree().create_timer(warp_duration).timeout
	
	parent.show()
	_set_collisions(true)
	set_process(true)
	
	if randf() < chance_of_death:
		var health = parent.get_node("Health")
		health.reduce_health(health.current_health)

# Toggle collision shapes on/off (mirrors health.die pattern)
func _set_collisions(enabled: bool) -> void:
	for child in parent.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", not enabled)
		elif child is Area2D:
			for shape in child.get_children():
				if shape is CollisionShape2D or shape is CollisionPolygon2D:
					shape.set_deferred("disabled", not enabled)

# Random position within screen bounds
func _random_position() -> Vector2:
	var viewport = get_viewport().get_visible_rect().size
	return Vector2(
		randf_range(20.0, viewport.x - 20.0),
		randf_range(20.0, viewport.y - 20.0)
	)
