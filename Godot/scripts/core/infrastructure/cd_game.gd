## CDGame
## Root node for every game scene — state machine and signal router
## Provides game bus (Dictionary-based), required child refs, and lifecycle
## Robust initialization: finds components even if nested in CDStage, or creates them with defaults.

class_name CDGame extends Node2D

## play area bounds used by entities for clamping and spawning
@export var game_bounds: Rect2

## infrastructure component references (initialized in _ready)
## supports nested structures (e.g., inside CDStage) or auto-creation
var collision_buffer: CDCollisionBuffer
var group_registry: CDGroupRegistry
var collision_matrix: CDCollisionMatrix
var input_router: CDInputRouter
var update: CDUpdater

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

	## 1. Robust Infrastructure Initialization
	## Attempts to find existing components (even if nested) or creates them with defaults.
	_ensure_infrastructure()

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

	## wire internal game over listener to the game bus
	bus_connect("game_over", _end_game_from_bus)

	## create attract mode label
	_attract_label = Label.new()
	_attract_label.text = "PRESS ENTER TO START"
	_attract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attract_label.position = Vector2(0, 10)
	_attract_label.size = Vector2(480, 20)
	add_child(_attract_label)

## --- Infrastructure Initialization ---

## Finds or creates required infrastructure components.
## 1. Tries to find a child by exact name.
## 2. Tries to find a child by class type (handles nesting).
## 3. Creates a new instance with defaults if missing.
func _ensure_infrastructure() -> void:
	collision_buffer = _find_or_create(CDCollisionBuffer, "CDCollisionBuffer")
	group_registry = _find_or_create(CDGroupRegistry, "CDGroupRegistry")
	collision_matrix = _find_or_create(CDCollisionMatrix, "CDCollisionMatrix")
	input_router = _find_or_create(CDInputRouter, "CDInputRouter")
	update = _find_or_create(CDUpdater, "CDUpdater")

## Generic helper to find an existing node or create a new one.
func _find_or_create(script_class: GDScript, default_name: StringName) -> Node:
	## 1. Try exact match by name (direct child or recursive)
	var node := find_child(default_name, true, false)
	
	## 2. If not found by name, try to find any instance of this class in the scene tree
	if not node:
		## find_children returns Array, filter by specific class type match
		var candidates := find_children("*", "", true, false)
		for candidate in candidates:
			## verify exact type match by comparing script resources
			if candidate.get_script() == script_class:
				node = candidate
				break
	
	## 3. Create default instance if still missing
	if not node:
		node = script_class.new()
		node.name = default_name
		add_child(node)
		push_warning("CDGame: Auto-created missing infrastructure component '%s' with default settings." % default_name)
	
	return node

## --- Game Bus API ---

## bus connect — idempotent: guards against double-connection
func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not has_signal(signal_name):
		add_user_signal(signal_name)
	if not is_connected(signal_name, callable):
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

## reads result from blackboard and triggers state transition
func _end_game_from_bus() -> void:
	var result: CDEnums.GameResult = blackboard.get("game_result", CDEnums.GameResult.DEFEAT)
	end_game(result)

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
