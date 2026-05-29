## root node for every game scene, state machine and signal router
class_name CDGame extends Node2D

@export var game_bounds: Rect2

## required nodes for game are placed in editor for easy configuration
@onready var collision_buffer: CDCollisionBuffer = $CDCollisionBuffer
@onready var group_registry: CDGroupRegistry = $CDGroupRegistry
@onready var collision_matrix: CDCollisionMatrix = $CDCollisionMatrix
@onready var input_router: CDInputRouter = $CDInputRouter
@onready var update: CDUpdater = $CDUpdater

var _current_state: CDEnums.GameState = CDEnums.GameState.ATTRACT
var _attract_label: Label

var current_state: CDEnums.GameState:
	get:
		return _current_state
	set(value):
		if _current_state != value:
			_current_state = value
			bus_emit("game_state_changed", [value])
			if _current_state == CDEnums.GameState.PLAYING:
				_attract_label.visible = (current_state == CDEnums.GameState.ATTRACT)

var _bus: Dictionary = {}  # {StringName: Array[Callable]}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# CDGame pauses others, it does not get paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	input_router.process_mode = Node.PROCESS_MODE_ALWAYS

	# wait until the game starts
	get_tree().paused = true

	# setup collision matrix
	if collision_matrix and not collision_matrix.collision_groups.is_empty():
		collision_matrix.build_maps()
		for entity in find_children("*", "CDEntity"):
			collision_matrix.configure(entity)

	# connect to input router
	if input_router:
		input_router.start_pressed.connect(start_game)
		input_router.restart_pressed.connect(reset_game)
		input_router.quit_pressed.connect(_quit_game)
	
	_attract_label = Label.new()
	_attract_label.text = "PRESS ENTER TO START"
	_attract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attract_label.position = Vector2(0, 10)
	_attract_label.size = Vector2(480, 20)
	add_child(_attract_label)

### bus methods

func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not _bus.has(signal_name):
		_bus[signal_name] = []
	_bus[signal_name].append(callable)

func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
	if _bus.has(signal_name):
		_bus[signal_name].erase(callable)
		if _bus[signal_name].is_empty():
			_bus.erase(signal_name)

## fast path emission for simple bus signals
func bus_emit(signal_name: StringName, args: Array = []) -> void:
	if not _bus.has(signal_name):
		return
	var callables = _bus[signal_name]
	if args.is_empty():
		for c in callables:
			c.call()
	elif args.size() == 1:
		for c in callables:
			c.call(args[0])
	else:
		for c in callables:
			c.callv(args)

### state management

func start_game() -> void:
	if _current_state != CDEnums.GameState.ATTRACT:
		return
	get_tree().paused = false
	current_state = CDEnums.GameState.PLAYING
	bus_emit("game_play")

func end_game(result: CDEnums.GameResult) -> void:
	if _current_state == CDEnums.GameState.GAME_OVER:
		return
	get_tree().paused = true
	current_state = CDEnums.GameState.GAME_OVER
	bus_emit("game_over", [result])

func pause_game() -> void:
	if _current_state == CDEnums.GameState.PLAYING:
		current_state = CDEnums.GameState.PAUSED

func unpause_game() -> void:
	if _current_state == CDEnums.GameState.PAUSED:
		current_state = CDEnums.GameState.PLAYING

## reload scene with godot method
func reset_game() -> void:
	get_tree().reload_current_scene()

func _quit_game() -> void:
	get_tree().quit()

## helper method
static func find_ancestor(node: Node) -> CDGame:
	var parent = node.get_parent()
	while parent:
		if parent is CDGame:
			return parent
		parent = parent.get_parent()
	return null
