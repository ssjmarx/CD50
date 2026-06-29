## ai_tractor_beam_brain.gd
## Produces: a tractor-beam capture attempt (start/arm-fire/end game+entity bus signals) honoring a global capture limit.
## Consumes: trigger_signals + arm_complete_signals (entity bus); game.blackboard capture_limit_key; qualifying_groups filter.
class_name AITractorBeamBrain extends CDEntityComponent

@export var max_captures: int = 1

@export var qualifying_groups: Array[StringName] = [&"diving"]

## The blackboard key to read to check the current number of active captures.
## If left empty, no limit is enforced (legacy behavior).
@export var capture_limit_key: StringName = &"active_capture_count"

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

## Set the intent category before the base _ready brain lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## Connect each trigger and arm-complete signal during initialization.
func _on_initialize() -> void:
	for sig in trigger_signals:
		self.bus_connect(sig, _on_trigger)
	for sig in arm_complete_signals:
		self.bus_connect(sig, _on_arm_complete)

## triggered by CDMark entity bus signal
func _on_trigger() -> void:
	if _is_capturing or not _qualifies():
		return
		
	## Check global capture limit if a key is configured
	if not capture_limit_key.is_empty():
		var current_captures: int = game.blackboard.get(capture_limit_key, 0)
		if current_captures >= max_captures:
			return ## Limit reached, ignore trigger
			
	_begin_capture()

## Zero the entity velocity, flag capturing, write capturing_entity, then emit start and arm-fire signals.
func _begin_capture() -> void:
	_is_capturing = true
	entity.request_velocity_set(Vector2.ZERO)
	game.blackboard[capturing_entity_key] = entity
	for sig in capture_started_signals:
		game.bus_emit(sig)
	for sig in arm_fire_signals:
		entity.bus_emit(sig)

## End the capture phase when the arm reports completion.
func _on_arm_complete() -> void:
	if not _is_capturing:
		return
	_is_capturing = false
	for sig in capture_ended_signals:
		game.bus_emit(sig)

## Reset capturing state and disconnect all trigger/arm-complete signals on entity deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false
	
	for sig in trigger_signals:
		self.bus_disconnect(sig, _on_trigger)
	for sig in arm_complete_signals:
		self.bus_disconnect(sig, _on_arm_complete)

## Return true if qualifying_groups is empty or the entity is in one of them.
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false
