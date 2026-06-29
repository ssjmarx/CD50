## tractor_beam_arm.gd
## Produces: a tractor-beam capture payload via an immediate physics overlap query (writes game/target blackboards, emits capture/miss/complete signals).
## Consumes: fire_signals (fire_tractor_beam); beam_shape; target_groups filter (resolved to collision_mask).
class_name TractorBeamArm extends CDEntityComponent

## frames to wait before capture attempt
@export var windup_frames: int = 60

## frames to hold after capture attempt
@export var hold_frames: int = 30

## the shape used for the immediate physics overlap query
@export var beam_shape: Shape2D

## collision mask for the physics query (dynamically resolved in _on_initialize)
@export_flags_2d_physics var collision_mask: int = 1

@export_group("Target Filtering")
## groups to filter for (empty = allow all). Used to resolve the collision mask dynamically.
@export var target_groups: Array[StringName] = []

@export_group("Blackboard Keys")
## key to write the captured entity to on the game blackboard
@export var target_blackboard_key: StringName = &"captured_entity"
## key to write the captor (self) to on the target's entity blackboard
@export var captor_blackboard_key: StringName = &"captured_by"

@export_group("Listen Signals")
@export var fire_signals: Array[StringName] = [&"fire_tractor_beam"]

@export_group("Emit Signals")
@export var windup_signals: Array[StringName] = [&"tractor_beam_windup"]
@export var capture_signals: Array[StringName] = [&"player_captured"]
@export var captured_signals: Array[StringName] = [&"capture_succeeded"]
@export var miss_signals: Array[StringName] = [&"capture_missed"]
@export var complete_signals: Array[StringName] = [&"tractor_beam_complete"]

## whether the tractor beam is currently active
var _is_active: bool = false

## frame counter for windup/hold timing
var _frame_count: int = 0

## whether capture has already been attempted this activation
var _capture_attempted: bool = false

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## Connect each fire signal and dynamically resolve the collision mask from target groups.
func _on_initialize() -> void:
	## Dynamic mask resolution based on target groups
	var mask := 0
	if game:
		var cm = game.get("collision_matrix")
		if cm and cm.has_method("get_layer_for_group"):
			for group_name in target_groups:
				mask |= cm.get_layer_for_group(group_name)
	collision_mask = mask

	for sig in fire_signals:
		self.bus_connect(sig, _on_fire)

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

## frame-based windup -> capture -> hold sequence
func _physics_process(_delta: float) -> void:
	if not _is_active:
		set_physics_process(false)
		return

	_frame_count += 1

	## at windup_frames: attempt capture using immediate physics query
	if _frame_count == windup_frames and not _capture_attempted:
		_capture_attempted = true
		_attempt_capture()

	if _frame_count >= windup_frames + hold_frames:
		_end_tractor_beam()

## execute the immediate physics overlap query
func _attempt_capture() -> void:
	if not beam_shape:
		push_warning("TractorBeamArm has no beam_shape assigned!")
		_emit_miss()
		return

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = beam_shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var intersections = space_state.intersect_shape(query)
	for intersection in intersections:
		var collider = intersection.collider
		if _passes_filter(collider):
			_execute_capture(collider)
			return

	_emit_miss()

## write capture data to game blackboard, target blackboard, and emit signals
func _execute_capture(target: CDEntity) -> void:
	## write to game blackboard
	game.blackboard[target_blackboard_key] = target
	
	## write to target's entity blackboard
	target.blackboard[captor_blackboard_key] = entity
	
	## emit on target's entity bus
	for sig in capture_signals:
		target.bus_emit(sig)
	
	## emit on captor's entity bus
	for sig in captured_signals:
		entity.bus_emit(sig)

## emit miss signals if no valid target was found
func _emit_miss() -> void:
	for sig in miss_signals:
		entity.bus_emit(sig)

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
		self.bus_disconnect(sig, _on_fire)

## return true if body matches any filter group (or all if no filter)
func _passes_filter(body: Node) -> bool:
	if target_groups.is_empty():
		return true
	for g in target_groups:
		if body.is_in_group(g):
			return true
	return false
