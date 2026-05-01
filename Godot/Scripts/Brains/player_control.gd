# Player control brain. Reads keyboard, mouse, and gamepad input, then emits signals directly to the parent body.

extends UniversalComponent

var using_mouse: bool = false

# Forward mouse motion and button press/release to parent output signals
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		parent.move_to.emit(event.position)
		parent.aim_at.emit(event.position)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			parent.action.emit(event)
			if event.is_action("button_r"):
				parent.shoot.emit()
			if event.is_action("button_l"):
				parent.thrust.emit()
		if event.is_released():
			parent.end_action.emit()
			if event.is_action("button_r"):
				parent.end_shoot.emit()
			if event.is_action("button_l"):
				parent.end_thrust.emit()

# Emit move and aim signals every physics frame from input axes
func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	direction.x = Input.get_axis("button_left", "button_right")
	parent.move.emit(direction)
	
	var aim_dir: Vector2 = Vector2.ZERO
	aim_dir.y = Input.get_axis("aim_up", "aim_down")
	aim_dir.x = Input.get_axis("aim_left", "aim_right")
	parent.aim.emit(aim_dir)