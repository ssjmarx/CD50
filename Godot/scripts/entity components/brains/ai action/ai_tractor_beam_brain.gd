# AITractorBeamBrain
# Interrupts a dive to perform a tractor beam capture attempt
# Fires the tractor beam arm when entity reaches trigger_height during a qualifying dive

class_name AITractorBeamBrain extends CDEntityComponent

# entity must be in one of these groups to trigger
@export var qualifying_groups: Array[StringName] = [&"diving"]

# Y position threshold to trigger the capture
@export var trigger_height: float = 200.0

@export_group("Listen Signals")
@export var arm_complete_signals: Array[StringName] = [&"tractor_beam_complete"]

@export_group("Emit Signals")
@export var arm_fire_signals: Array[StringName] = [&"fire_tractor_beam"]
@export var capture_started_signals: Array[StringName] = [&"capture_phase_started"]
@export var capture_ended_signals: Array[StringName] = [&"capture_phase_ended"]

# whether currently in capture phase
var _is_capturing: bool = false

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure signals exist and connect arm completion listener
func _on_initialize() -> void:
	for sig in arm_fire_signals:
		entity.ensure_signal(sig)
	for sig in capture_started_signals:
		entity.ensure_signal(sig)
	for sig in capture_ended_signals:
		entity.ensure_signal(sig)
	for sig in arm_complete_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_arm_complete)

# check trigger conditions and begin capture when entity is low enough
func _physics_process(_delta: float) -> void:
	if _is_capturing:
		return
	if not _qualifies():
		return
	if entity.global_position.y >= trigger_height:
		_begin_capture()

# halt movement, notify game, and fire the tractor beam arm
func _begin_capture() -> void:
	_is_capturing = true
	entity.request_velocity_set(Vector2.ZERO)
	for sig in capture_started_signals:
		game.bus_emit(sig, [entity])
	for sig in arm_fire_signals:
		entity.emit_signal(sig)

# resume from capture when the tractor beam arm completes
func _on_arm_complete(_arg1: Variant = null) -> void:
	if not _is_capturing:
		return
	_is_capturing = false
	for sig in capture_ended_signals:
		game.bus_emit(sig, [entity])

# return true if entity is in at least one qualifying group (empty = always qualifies)
func _qualifies() -> bool:
	if qualifying_groups.is_empty():
		return true
	for group_name: StringName in qualifying_groups:
		if entity.is_in_group(group_name):
			return true
	return false

# clean up capture state and disconnect signals
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_capturing = false
	for sig in arm_complete_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_arm_complete):
			entity.disconnect(sig, _on_arm_complete)