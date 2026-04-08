extends Node

var using_mouse: bool = false

@onready var parent = get_parent()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		using_mouse = true

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	direction.x = Input.get_axis("button_left", "button_right")
	
	if direction != Vector2.ZERO:
		using_mouse = false
		parent.set_direct_movement(direction)
	elif using_mouse:
		var mouse_pos = parent.get_global_mouse_position()
		parent.set_target_coords(mouse_pos)
	else:
		parent.set_direct_movement(Vector2.ZERO)
