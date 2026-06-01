# AITractorBeamBrain
# Interrupts a dive to perform a tractor beam capture attempt
# Fires the tractor beam arm when entity reaches trigger_height during a qualifying dive

class_name AITractorBeamBrain extends CDEntityComponent

@export var qualifying_groups: Array[StringName] = [&"diving"]
@export var trigger_height: float = 200.0

@export_group("Listen Signals")
@export var arm_complete_signals: Array[StringName] = [&"tractor_beam_complete"]

@export_group("Emit Signals")
@export var arm_fire_signals: Array[StringName] = [&"fire_tractor_beam"]
@export var capture_started_signals: Array[StringName] = [&"capture_phase_started"]
@export var capture_ended_signals: Array[StringName] = [&"capture_phase_ended"]

@export_group("Game Blackboard")
@export var capturing_entity_key: StringName = &"capturing_entity"

var _is_capturing: bool = false

func _on_initialize() -> void:
	for sig in arm_complete_signals:
		entity.bus_connect(sig, _on_arm_complete)

func _physics_process(_delta: float) -> void:
	if _is_capturing or not _qualifies():
		return
	if entity.global_position.y >= trigger_height:
		_begin_capture()

func _begin_capture() -> void:
	_is_capturing = true
	entity.request_velocity_set(Vector2.ZERO)
	game.blackboard[capturing_entity_key] = entity
	for sig in capture_started_signals:
		game.bus_emit(sig)
	for sig in arm_fire_signals:
		entity.bus_emit(sig)

func _on_arm_complete() -> void:
	if not _is_capturing: return
	_is_capturing = false
	game.blackboard[capturing_entity_key] = entity
	for sig in capture_ended_signals:
		game.bus_emit(sig)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false
	for sig in arm_complete_signals:
		entity.bus_disconnect(sig, _on_arm_complete)

func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false
