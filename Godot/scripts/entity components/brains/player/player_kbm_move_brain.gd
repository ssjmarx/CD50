## PlayerKBMMoveBrain
## Unified keyboard + mouse movement brain for KBM control schemes
## Uses input mode state machine: NONE → KEYBOARD (on key press) → NONE (on release) → MOUSE (on mouse move)

class_name PlayerKBMMoveBrain extends CDEntityComponent

@export var player_id: int = 1

## mouse follow stops when cursor is closer than this
@export var dead_zone: float = 4.0

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

enum _InputMode { NONE, KEYBOARD, MOUSE }

var _mode: _InputMode = _InputMode.NONE
var _kb_direction: Vector2 = Vector2.ZERO
var _last_mouse_pos: Vector2 = Vector2.INF

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## on initialize
func _on_initialize() -> void:
	game.input_router.input_move.connect(_on_input_move)

## on input move
func _on_input_move(pid: int, direction: Vector2) -> void:
	if pid != player_id:
		return
	if direction != Vector2.ZERO:
		_mode = _InputMode.KEYBOARD
	_kb_direction = direction

## physics process
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	match _mode:
		_InputMode.KEYBOARD:
			if _kb_direction != Vector2.ZERO:
				entity.blackboard[move_key] = _kb_direction
				entity.blackboard[distance_key] = 0.0
			else:
				entity.blackboard[move_key] = Vector2.ZERO
				entity.blackboard[distance_key] = 0.0
				_mode = _InputMode.NONE

		_InputMode.NONE:
			entity.blackboard[move_key] = Vector2.ZERO
			entity.blackboard[distance_key] = 0.0
			var mouse_pos := entity.get_global_mouse_position()
			if mouse_pos != _last_mouse_pos:
				_last_mouse_pos = mouse_pos
				_mode = _InputMode.MOUSE

		_InputMode.MOUSE:
			var mouse_pos := entity.get_global_mouse_position()
			_last_mouse_pos = mouse_pos
			var to_target := mouse_pos - entity.global_position
			var distance := to_target.length()

			if distance <= dead_zone:
				entity.blackboard[move_key] = Vector2.ZERO
				entity.blackboard[distance_key] = 0.0
			else:
				entity.blackboard[move_key] = to_target.normalized()
				entity.blackboard[distance_key] = distance

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_mode = _InputMode.NONE
	_kb_direction = Vector2.ZERO
	_last_mouse_pos = Vector2.INF
	set_physics_process(false)
	if is_instance_valid(game) and game.input_router:
		if game.input_router.input_move.is_connected(_on_input_move):
			game.input_router.input_move.disconnect(_on_input_move)