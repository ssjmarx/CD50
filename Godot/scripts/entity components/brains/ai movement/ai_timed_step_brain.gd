# AITimedStepBrain
# Writes a directional value to the blackboard at a regular interval
# Reads step_interval and step_direction from the blackboard each step (falls back to export defaults)
# Any component can modulate step behavior by writing to the configured blackboard keys

class_name AITimedStepBrain extends CDEntityComponent

# default interval (used when blackboard key is not set)
@export var step_interval: float = 1.0

# default direction (used when blackboard key is not set)
@export var step_direction: Vector2 = Vector2.DOWN

@export_group("Blackboard Keys")
@export var step_interval_key: StringName = &"step_interval"
@export var step_direction_key: StringName = &"step_direction"
@export var move_key: StringName = &"move_direction"

@export_group("Listen Signals")
@export var reset_signals: Array[StringName] = [&"reset_step"]

# time since last step
var _timer: float = 0.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in reset_signals:
		entity.bus_connect(sig, _on_reset)

# read interval and direction from blackboard, write move on each step
func _physics_process(delta: float) -> void:
	_timer += delta
	var interval: float = entity.blackboard.get(step_interval_key, step_interval)
	if _timer >= interval:
		_timer = 0.0
		var direction: Vector2 = entity.blackboard.get(step_direction_key, step_direction)
		entity.blackboard[move_key] = direction

# clear overrides so defaults kick back in
func _on_reset() -> void:
	_timer = 0.0
	entity.blackboard.erase(step_interval_key)
	entity.blackboard.erase(step_direction_key)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_timer = 0.0
	for sig in reset_signals:
		entity.bus_disconnect(sig, _on_reset)