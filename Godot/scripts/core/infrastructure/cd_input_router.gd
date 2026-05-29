## autoloaded pure signal driven input handler
class_name CDInputRouter extends Node

## direction movement (left analog stick)
signal input_move(player_id: int, direction: Vector2)

## aim (right analog stick)
signal input_aim(player_id: int, direction: Vector2)

## buttons (button name is the action)
signal input_action_pressed(player_id: int, action: StringName)
signal input_action_released(player_id: int, action: StringName)

## virtual buttons for system commands
signal start_pressed
signal restart_pressed
signal quit_pressed
signal pause_pressed

@export var player_count: int = 1

## gameplay actions [&"fire", &"jump", &"special", etc]
@export var tracked_actions: Array[StringName] = [&"fire"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(_delta: float) -> void:
	# system buttons — always active (needed to unpause!)
	if Input.is_action_just_pressed("start"):
		start_pressed.emit()
	if Input.is_action_just_pressed("restart"):
		restart_pressed.emit()
	if Input.is_action_just_pressed("quit"):
		quit_pressed.emit()
	if Input.is_action_just_pressed("pause"):
		pause_pressed.emit()

	# gameplay input — only when unpaused
	if get_tree().paused:
		return

	# per player input (movement + actions)
	for i in range(player_count):
		var player_id := i + 1
		var prefix := "p%d_" % player_id if player_count > 1 else ""

		# movement
		var move_dir := Input.get_vector(
			prefix + "move_left", prefix + "move_right",
			prefix + "move_up", prefix + "move_down"
		)
		input_move.emit(player_id, move_dir)

		# aim
		var aim_dir := Input.get_vector(
			prefix + "aim_left", prefix + "aim_right",
			prefix + "aim_up", prefix + "aim_down"
		)
		if aim_dir != Vector2.ZERO:
			input_aim.emit(player_id, aim_dir)

		# buttons
		for action in tracked_actions:
			var full_action := prefix + String(action)
			if Input.is_action_just_pressed(full_action):
				input_action_pressed.emit(player_id, action)
			if Input.is_action_just_released(full_action):
				input_action_released.emit(player_id, action)
