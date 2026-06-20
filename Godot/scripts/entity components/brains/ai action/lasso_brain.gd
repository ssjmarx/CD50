## LassoBrain
## Triggers the lasso firing sequence by listening for the mark signal.
## Identical signal flow to AITractorBeamBrain to ensure compatibility with capture mechanics.

class_name LassoBrain extends CDEntityComponent

@export var qualifying_groups: Array[StringName] = [&"diving"]

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"fire_tractor_beam"]
@export var arm_complete_signals: Array[StringName] = [&"tractor_beam_complete"]

@export_group("Emit Signals")
@export var arm_fire_signals: Array[StringName] = [&"fire_tractor_beam"]
@export var capture_started_signals: Array[StringName] = [&"capture_phase_started"]
@export var capture_ended_signals: Array[StringName] = [&"capture_phase_ended"]

@export_group("Game Blackboard")
@export var capturing_entity_key: StringName = &"capturing_entity"

var _is_capturing: bool = false

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in trigger_signals:
		self.bus_connect(sig, _on_trigger)
	for sig in arm_complete_signals:
		self.bus_connect(sig, _on_arm_complete)

## triggered by CDMark entity bus signal
func _on_trigger() -> void:
	if _is_capturing or not _qualifies():
		return
	_begin_capture()

## begin capture
func _begin_capture() -> void:
	_is_capturing = true
	entity.request_velocity_set(Vector2.ZERO)
	game.blackboard[capturing_entity_key] = entity
	for sig in capture_started_signals:
		game.bus_emit(sig)
	for sig in arm_fire_signals:
		entity.bus_emit(sig)

## on arm complete
func _on_arm_complete() -> void:
	if not _is_capturing:
		return
	_is_capturing = false
	for sig in capture_ended_signals:
		game.bus_emit(sig)

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false
	for sig in trigger_signals:
		self.bus_disconnect(sig, _on_trigger)
	for sig in arm_complete_signals:
		self.bus_disconnect(sig, _on_arm_complete)

## qualifies
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false
