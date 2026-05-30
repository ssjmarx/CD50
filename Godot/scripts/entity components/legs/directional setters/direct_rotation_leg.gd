# DirectRotationLeg
# Tank-style continuous rotation from directional input and/or action signals
# Combines directional X-axis spin with discrete left/right action buttons

class_name DirectRotationLeg extends CDEntityComponent

# --- exports ---

# rotation speed in degrees per second
@export var rotation_speed: float = 180.0

# directional input signals (Vector2, uses X component)
@export_group("Directional Input")
@export var move_signals: Array[StringName] = [&"move"]

# discrete rotation action names
@export_group("Action Input")
@export var rotate_left_action: StringName = &"rotate_left"
@export var rotate_right_action: StringName = &"rotate_right"
# action press/release signals (StringName action)
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

# --- state ---

# spin from directional input (X axis only)
var _directional_spin: float = 0.0
# whether left action is held
var _spinning_left: bool = false
# whether right action is held
var _spinning_right: bool = false

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# connect directional and action listeners
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

# --- signal handlers ---

# extract X component from directional input as spin intensity
func _on_move(direction: Vector2) -> void:
	_directional_spin = direction.x

# start spinning on action press
func _on_action(action: StringName) -> void:
	if action == rotate_left_action:
		_spinning_left = true
	elif action == rotate_right_action:
		_spinning_right = true

# stop spinning on action release
func _on_action_end(action: StringName) -> void:
	if action == rotate_left_action:
		_spinning_left = false
	elif action == rotate_right_action:
		_spinning_right = false

# --- processing ---

# combine directional spin + action buttons, apply as angular velocity
func _physics_process(_delta: float) -> void:
	var spin := _directional_spin
	if _spinning_left:
		spin -= 1.0
	if _spinning_right:
		spin += 1.0
	
	# apply angular velocity or zero it
	if spin != 0.0:
		var radians_per_sec := deg_to_rad(rotation_speed)
		entity.request_angular_set(spin * radians_per_sec)
	else:
		entity.request_angular_set(0.0)

# --- cleanup ---

# reset state and disconnect all listeners for pool reuse
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
