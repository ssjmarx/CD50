# Player control brain. Reads keyboard/mouse/gamepad and emits input signals to parent.

extends UniversalComponent

var using_mouse: bool = false # Track if mouse is being used


# Handle mouse and button inputs
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		parent.mouse_position.emit(event.position)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			parent.button_pressed.emit(event)
		if event.is_released():
			parent.button_released.emit(event)

# Emit joystick direction signals every frame
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	direction.x = Input.get_axis("button_left", "button_right")
	parent.left_joystick.emit(direction)
	
	var aim_dir: Vector2 = Vector2.ZERO
	aim_dir.y = Input.get_axis("aim_up", "aim_down")
	aim_dir.x = Input.get_axis("aim_left", "aim_right")
	parent.right_joystick.emit(aim_dir)
