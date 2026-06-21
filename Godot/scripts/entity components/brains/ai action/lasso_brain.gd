## LassoBrain
## Triggers the lasso firing sequence by listening for the mark signal.
## Checks a global blackboard key to enforce a maximum number of simultaneous captures.
## Emits a start signal, fires the lasso, and then emits an end signal after a short duration.
## This allows the spider to halt, shoot, and then seamlessly return to formation.

class_name LassoBrain extends CDEntityComponent

@export var max_captures: int = 1

@export var qualifying_groups: Array[StringName] = [&"diving"]
@export var capture_duration: float = 1.0

## The blackboard key to read to check the current number of active captures.
## If left empty, no limit is enforced (legacy behavior).
@export var capture_limit_key: StringName = &"active_capture_count"

@export_group("Listen Signals")
@export var trigger_signals: Array[StringName] = [&"fire_tractor_beam"]

@export_group("Emit Signals")
@export var lasso_start_signals: Array[StringName] = [&"lasso_start"]
@export var lasso_end_signals: Array[StringName] = [&"lasso_end"]
@export var arm_fire_signals: Array[StringName] = [&"fire_tractor_beam"]

var _is_capturing: bool = false
var _timer: Timer

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()
	
	_timer = Timer.new()
	_timer.wait_time = capture_duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

## on initialize
func _on_initialize() -> void:
	for sig in trigger_signals:
		self.bus_connect(sig, _on_trigger)

## triggered by CDMark entity bus signal
func _on_trigger() -> void:
	if _is_capturing or not _qualifies():
		return
		
	# Check global capture limit if a key is configured
	if not capture_limit_key.is_empty():
		var current_captures: int = game.blackboard.get(capture_limit_key, 0)
		if current_captures >= max_captures:
			return # Limit reached, ignore trigger
			
	_begin_capture()

## begin capture
func _begin_capture() -> void:
	_is_capturing = true
	
	# Emit start signals (can be routed to stop divebomb)
	for sig in lasso_start_signals:
		entity.bus_emit(sig)
		
	# Fire the lasso arm
	for sig in arm_fire_signals:
		entity.bus_emit(sig)
		
	_timer.start()

## on timer timeout
func _on_timer_timeout() -> void:
	if not _is_capturing:
		return
	_is_capturing = false
	
	# Emit end signals (can be routed to join formation)
	for sig in lasso_end_signals:
		entity.bus_emit(sig)

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false
	
	if _timer:
		_timer.stop()
		
	for sig in trigger_signals:
		if entity.is_connected(sig, _on_trigger):
			entity.bus_disconnect(sig, _on_trigger)

## qualifies
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false
