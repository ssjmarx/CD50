## tank-style continuous rotation from directional input and/or action signals
class_name DirectRotationLeg extends CDEntityComponent

@export var rotation_speed: float = 180.0  # degrees per second

@export_group("Directional Input")
@export var move_signals: Array[StringName] = [&"move"]

@export_group("Action Input")
@export var rotate_left_action: StringName = &"rotate_left"
@export var rotate_right_action: StringName = &"rotate_right"
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

var _directional_spin: float = 0.0
var _spinning_left: bool = false
var _spinning_right: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)
	for sig in action_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_action)
	for sig in action_end_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_action_end)

func _on_move(direction: Vector2) -> void:
	_directional_spin = direction.x  # strip Y, use X

func _on_action(action: StringName) -> void:
	if action == rotate_left_action:
		_spinning_left = true
	elif action == rotate_right_action:
		_spinning_right = true

func _on_action_end(action: StringName) -> void:
	if action == rotate_left_action:
		_spinning_left = false
	elif action == rotate_right_action:
		_spinning_right = false

func _physics_process(_delta: float) -> void:
	var spin := _directional_spin
	if _spinning_left:
		spin -= 1.0
	if _spinning_right:
		spin += 1.0
	
	if spin != 0.0:
		var radians_per_sec := deg_to_rad(rotation_speed)
		entity.request_angular_set(spin * radians_per_sec)
	else:
		entity.request_angular_set(0.0)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_directional_spin = 0.0
	_spinning_left = false
	_spinning_right = false
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)
	for sig in action_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_action):
			entity.disconnect(sig, _on_action)
	for sig in action_end_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_action_end):
			entity.disconnect(sig, _on_action_end)
