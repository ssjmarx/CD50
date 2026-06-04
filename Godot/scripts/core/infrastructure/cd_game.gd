## CDGame
## Root node for every game scene — state machine and signal router
## Provides game bus (Dictionary-based), required child refs, and lifecycle

class_name CDGame extends Node2D

## play area bounds used by entities for clamping and spawning
@export var game_bounds: Rect2

## required infrastructure children — placed in editor for easy configuration
@onready var collision_buffer: CDCollisionBuffer = $CDCollisionBuffer
@onready var group_registry: CDGroupRegistry = $CDGroupRegistry
@onready var collision_matrix: CDCollisionMatrix = $CDCollisionMatrix
@onready var input_router: CDInputRouter = $CDInputRouter
@onready var update: CDUpdater = $CDUpdater

## blackboard for shared game state
var blackboard: Dictionary = {}

## per-frame signal emitter tracking (populated by bus_emit_from, cleared by CDUpdater)
var _signal_emitters: Dictionary = {}  # {StringName: Array}

## --- State Machine ---

var _current_state: CDEnums.GameState = CDEnums.GameState.ATTRACT
var _attract_label: Label

## state setter — emits game_state_changed on the bus
var current_state: CDEnums.GameState:
	get:
		return _current_state
	set(value):
		if _current_state != value:
			_current_state = value
			bus_emit("game_state_changed")
			if _current_state == CDEnums.GameState.PLAYING:
				_attract_label.visible = (current_state == CDEnums.GameState.ATTRACT)

## --- Setup ---

## configure process modes, build collision matrix, wire input router
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE

	input_router.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().paused = true

	## build collision layer/mask maps from CDCollisionGroup resources
	if collision_matrix and not collision_matrix.collision_groups.is_empty():
		collision_matrix.build_maps()
		for node in find_children("*", "CollisionObject2D"):
			collision_matrix.configure(node)

	## wire input router system buttons to game lifecycle
	if input_router:
		input_router.start_pressed.connect(start_game)
		input_router.restart_pressed.connect(reset_game)
		input_router.quit_pressed.connect(_quit_game)

	## create attract mode label
	_attract_label = Label.new()
	_attract_label.text = "PRESS ENTER TO START"
	_attract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attract_label.position = Vector2(0, 10)
	_attract_label.size = Vector2(480, 20)
	add_child(_attract_label)

## --- Game Bus API ---

## bus connect
func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not has_signal(signal_name):
		add_user_signal(signal_name)
	connect(signal_name, callable)

## bus disconnect
func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
	if has_signal(signal_name) and is_connected(signal_name, callable):
		disconnect(signal_name, callable)

## bus emit — zero-arg signal, no emitter tracking (default)
func bus_emit(signal_name: StringName) -> void:
	if has_signal(signal_name):
		emit_signal(signal_name)

## bus emit from — zero-arg signal + tracks the emitting entity for this frame
func bus_emit_from(signal_name: StringName, emitter: Object) -> void:
	if not has_signal(signal_name):
		push_warning("CDGame.bus_emit_from: signal '%s' not registered" % signal_name)
		return
	emit_signal(signal_name)
	if not _signal_emitters.has(signal_name):
		_signal_emitters[signal_name] = []
	_signal_emitters[signal_name].append(emitter)

## --- State Transitions ---

## transition from ATTRACT → PLAYING, unpause the tree
func start_game() -> void:
	if _current_state != CDEnums.GameState.ATTRACT:
		return
	get_tree().paused = false
	blackboard.clear()
	current_state = CDEnums.GameState.PLAYING
	bus_emit("game_play")

## transition to GAME_OVER, pause the tree
func end_game(result: CDEnums.GameResult) -> void:
	if _current_state == CDEnums.GameState.GAME_OVER:
		return
	blackboard["game_result"] = result
	get_tree().paused = true
	current_state = CDEnums.GameState.GAME_OVER
	bus_emit("game_over")

## toggle pause state
func pause_game() -> void:
	if _current_state == CDEnums.GameState.PLAYING:
		current_state = CDEnums.GameState.PAUSED

## unpause back to playing
func unpause_game() -> void:
	if _current_state == CDEnums.GameState.PAUSED:
		current_state = CDEnums.GameState.PLAYING

## full scene reload via Godot
func reset_game() -> void:
	blackboard.clear()
	get_tree().reload_current_scene()

## exit the application
func _quit_game() -> void:
	get_tree().quit()

## --- Utility ---

## walk up the tree to find the nearest CDGame ancestor
static func find_ancestor(node: Node) -> CDGame:
	var parent = node.get_parent()
	while parent:
		if parent is CDGame:
			return parent
		parent = parent.get_parent()
	return null
