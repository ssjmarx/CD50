## adds forward velocity based on entity facing direction (asteroids-style).
## pair with FrictionLinear for speed control.
class_name EngineLeg extends CDEntityComponent

@export var thrust_action: StringName = &"thrust"
@export var thrust_power: float = 400.0

@export_group("Listen Signals")
@export var action_signals: Array[StringName] = [&"action"]
@export var action_end_signals: Array[StringName] = [&"action_end"]

var _is_thrusting: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

func _on_initialize() -> void:
	for sig in action_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_action)
	for sig in action_end_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_action_end)

func _on_action(action: StringName) -> void:
	if action == thrust_action:
		_is_thrusting = true

func _on_action_end(action: StringName) -> void:
	if action == thrust_action:
		_is_thrusting = false

func _physics_process(delta: float) -> void:
	if not _is_thrusting:
		return
	var forward := Vector2(cos(entity.rotation), sin(entity.rotation))
	entity.request_velocity_add(forward * thrust_power * delta)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_thrusting = false
	for sig in action_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_action):
			entity.disconnect(sig, _on_action)
	for sig in action_end_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_action_end):
			entity.disconnect(sig, _on_action_end)
