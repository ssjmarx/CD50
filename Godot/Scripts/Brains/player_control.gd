# Player control brain. Reads keyboard, mouse, and gamepad input via Input Map,
# then emits signals directly to the parent body. No _unhandled_input — fully Input Map-driven.

extends UniversalComponent

var using_mouse: bool = false

# Track input source and forward mouse position to parent signals
func _input(event: InputEvent) -> void:
	# Mouse motion → enable mouse mode, emit position signals
	if event is InputEventMouseMotion:
		using_mouse = true
		parent.move_to.emit(event.position)
		parent.aim_at.emit(event.position)
	
	# Joystick motion → disable mouse mode (gamepad takes over aiming)
	if event is InputEventJoypadMotion:
		using_mouse = false

# Emit move, aim, and button signals every physics frame from Input Map
func _physics_process(_delta: float) -> void:
	# Directional input
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	direction.x = Input.get_axis("button_left", "button_right")
	parent.move.emit(direction)
	
	var aim_dir: Vector2 = Vector2.ZERO
	aim_dir.y = Input.get_axis("aim_up", "aim_down")
	aim_dir.x = Input.get_axis("aim_left", "aim_right")
	parent.aim.emit(aim_dir)
	
	# Named buttons
	_emit_pressed("button_r", parent.shoot, parent.end_shoot)
	_emit_pressed("button_l", parent.thrust, parent.end_thrust)
	
	# Generic buttons
	_emit_pressed("button_1", parent.button_1, parent.end_button_1)
	_emit_pressed("button_2", parent.button_2, parent.end_button_2)
	_emit_pressed("button_3", parent.button_3, parent.end_button_3)
	_emit_pressed("button_4", parent.button_4, parent.end_button_4)
	_emit_pressed("button_5", parent.button_5, parent.end_button_5)
	_emit_pressed("button_6", parent.button_6, parent.end_button_6)
	
	# Number keys
	_emit_pressed("number_1", parent.number_1, parent.end_number_1)
	_emit_pressed("number_2", parent.number_2, parent.end_number_2)
	_emit_pressed("number_3", parent.number_3, parent.end_number_3)
	_emit_pressed("number_4", parent.number_4, parent.end_number_4)
	_emit_pressed("number_5", parent.number_5, parent.end_number_5)
	_emit_pressed("number_6", parent.number_6, parent.end_number_6)
	_emit_pressed("number_7", parent.number_7, parent.end_number_7)
	_emit_pressed("number_8", parent.number_8, parent.end_number_8)
	_emit_pressed("number_9", parent.number_9, parent.end_number_9)
	_emit_pressed("number_0", parent.number_0, parent.end_number_0)

# Helper: emit press/release signals for a given Input Map action
func _emit_pressed(action: String, press_signal: Signal, release_signal: Signal) -> void:
	if Input.is_action_just_pressed(action):
		press_signal.emit()
	if Input.is_action_just_released(action):
		release_signal.emit()