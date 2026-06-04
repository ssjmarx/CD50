## TractorBeamArm
## Frame-based arm that captures the entity's current target after a windup
## This arm handles: windup signal → read blackboard → capture → hold → complete

class_name TractorBeamArm extends CDEntityComponent

## frames to wait before capture attempt
@export var windup_frames: int = 30

## frames to hold after capture attempt
@export var hold_frames: int = 15

@export_group("Blackboard Keys")
@export var target_keys: Array[StringName] = [&"nearest_target"]
@export var captured_entity_keys: Array[StringName] = [&"captured_entity"]
@export var captured_by_keys: Array[StringName] = [&"captured_by"]

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"fire_tractor_beam"]

@export_group("Emit Signals")
@export var windup_signals: Array[StringName] = [&"tractor_beam_windup"]
@export var capture_signals: Array[StringName] = [&"player_captured"]
@export var miss_signals: Array[StringName] = [&"capture_missed"]
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]

## whether the tractor beam is currently active
var _is_active: bool = false

## frame counter for windup/hold timing
var _frame_count: int = 0

## whether capture has already been attempted this activation
var _capture_attempted: bool = false

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect fire signals, all emit signals are auto-created by bus_connect/bus_emit
func _on_initialize() -> void:
	for sig in fire_signals:
		entity.bus_connect(sig, _on_fire)

## start the tractor beam windup sequence
func _on_fire() -> void:
	if _is_active:
		return
	_is_active = true
	_frame_count = 0
	_capture_attempted = false
	set_physics_process(true)

	for sig in windup_signals:
		entity.bus_emit(sig)

## frame-based windup → capture → hold sequence
func _physics_process(_delta: float) -> void:
	if not _is_active:
		set_physics_process(false)
		return

	_frame_count += 1

	## at windup_frames: attempt capture of whatever is on the blackboard
	if _frame_count == windup_frames and not _capture_attempted:
		_capture_attempted = true
		for key in target_keys:
			var target = entity.blackboard.get(key)
			if is_instance_valid(target):
				## write capture data to game blackboard and notify
				for blackboard_key in captured_entity_keys:
					game.blackboard[blackboard_key] = target
				for blackboard_key in captured_by_keys:
					game.blackboard[blackboard_key] = entity
				for sig in capture_signals:
					game.bus_emit(sig)
			else:
				for sig in miss_signals:
					entity.bus_emit(sig)

	if _frame_count >= windup_frames + hold_frames:
		_end_tractor_beam()

## clean up active state and emit complete signals
func _end_tractor_beam() -> void:
	_is_active = false
	set_physics_process(false)
	for sig in complete_signals:
		entity.bus_emit(sig)

## disconnect all fire signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_active = false
	for sig in fire_signals:
		entity.bus_disconnect(sig, _on_fire)
