# CDInputRouter
# Pure signal-driven input handler — converts Godot Input actions into typed signals
# Runs in ALWAYS process mode so system buttons work while paused

class_name CDInputRouter extends Node

# --- Signals ---

# directional movement (left analog stick / WASD)
signal input_move(player_id: int, direction: Vector2)

# aim direction (right analog stick)
signal input_aim(player_id: int, direction: Vector2)

# gameplay action buttons (fire, jump, special, etc.)
signal input_action_pressed(player_id: int, action: StringName)
signal input_action_released(player_id: int, action: StringName)

# system buttons — always active
signal start_pressed
signal restart_pressed
signal quit_pressed
signal pause_pressed

# --- Exports ---

# number of players (1 = no prefix, 2+ = p1_/p2_ prefixes)
@export var player_count: int = 1

# gameplay actions to track for pressed/released events
@export var tracked_actions: Array[StringName] = [&"fire"]

# always process — needed to detect start/restart while paused
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- Input Processing ---

# poll system buttons every frame, gameplay input only when unpaused
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

	# per-player input: movement, aim, and action buttons
	for i in range(player_count):
		var player_id := i + 1
		var prefix := "p%d_" % player_id if player_count > 1 else ""

		# movement vector
		var move_dir := Input.get_vector(
			prefix + "move_left", prefix + "move_right",
			prefix + "move_up", prefix + "move_down"
		)
		input_move.emit(player_id, move_dir)

		# aim vector (only emitted when non-zero)
		var aim_dir := Input.get_vector(
			prefix + "aim_left", prefix + "aim_right",
			prefix + "aim_up", prefix + "aim_down"
		)
		if aim_dir != Vector2.ZERO:
			input_aim.emit(player_id, aim_dir)

		# action button pressed/released
		for action in tracked_actions:
			var full_action := prefix + String(action)
			if Input.is_action_just_pressed(full_action):
				input_action_pressed.emit(player_id, action)
			if Input.is_action_just_released(full_action):
				input_action_released.emit(player_id, action)