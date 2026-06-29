## lasso_brain.gd
## Produces: a timed lasso capture sequence (start → arm-fire → end) triggered by a mark signal, honoring a global capture limit.
## Consumes: trigger_signals (entity bus, from CDMark); game.blackboard capture_limit_key; qualifying_groups filter; capture_duration timer.
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

## Set the intent category and construct the one-shot capture-duration timer before the base _ready hook.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

	_timer = Timer.new()
	_timer.wait_time = capture_duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

## Connect each trigger signal during initialization.
func _on_initialize() -> void:
	for sig in trigger_signals:
		self.bus_connect(sig, _on_trigger)

## Triggered by a CDMark entity bus signal; qualifies the entity and checks the global capture limit before firing.
func _on_trigger() -> void:
	if _is_capturing or not _qualifies():
		return

	## Check global capture limit if a key is configured
	if not capture_limit_key.is_empty():
		var current_captures: int = game.blackboard.get(capture_limit_key, 0)
		if current_captures >= max_captures:
			return ## Limit reached, ignore trigger

	_begin_capture()

## Flag capturing, emit start signals (route to stop divebomb), fire the lasso arm, then start the end-timer.
func _begin_capture() -> void:
	_is_capturing = true

	## Emit start signals (can be routed to stop divebomb)
	for sig in lasso_start_signals:
		entity.bus_emit(sig)

	## Fire the lasso arm
	for sig in arm_fire_signals:
		entity.bus_emit(sig)

	_timer.start()

## Clear the capturing flag and emit end signals (route to join formation) when the capture-duration timer elapses.
func _on_timer_timeout() -> void:
	if not _is_capturing:
		return
	_is_capturing = false

	## Emit end signals (can be routed to join formation)
	for sig in lasso_end_signals:
		entity.bus_emit(sig)

## Reset capturing state, stop the timer, and disconnect all trigger signals on entity deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false

	if _timer:
		_timer.stop()

	for sig in trigger_signals:
		if entity.is_connected(sig, _on_trigger):
			entity.bus_disconnect(sig, _on_trigger)

## Return true if qualifying_groups is empty or the entity is in one of them.
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false