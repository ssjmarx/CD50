## ai_path_move_brain.gd
## Produces: move direction and distance along a baked Curve2D path (written to blackboard), advancing waypoints on arrival and honoring LOOP/RETRACE/ONCE patrol modes.
## Consumes: path_curve resource; move_key/distance_key blackboard keys; emits complete_signals on entity bus when ONCE finishes.
class_name AIPathMoveBrain extends CDEntityComponent

## the curve resource to follow
@export var path_curve: Curve2D

## spacing between baked waypoints along the curve
@export var waypoint_spacing: float = 20.0

## distance to consider a waypoint reached
@export var arrival_distance: float = 5.0

## how to behave when the path ends
@export var patrol_mode: CDEnums.PatrolMode = CDEnums.PatrolMode.LOOP

## if false, offset waypoints by entity's spawn position
@export var use_global_coords: bool = false

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Emit Signals")
@export var complete_signals: Array[StringName] = [&"patrol_complete"]

## baked waypoint positions
var _waypoints: Array[Vector2] = []

## current waypoint index
var _current_index: int = 0

## traversal direction (+1 forward, -1 reverse for RETRACE)
var _direction: int = 1

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## bake waypoints from the curve
func _on_initialize() -> void:
	_build_waypoints()

## sample the curve at regular intervals to build waypoint array
func _build_waypoints() -> void:
	if not path_curve or path_curve.point_count < 2:
		return
	_waypoints.clear()
	var total_length := path_curve.get_baked_length()
	var dist := 0.0
	while dist <= total_length:
		var pos := path_curve.sample_baked(dist)
		## offset by spawn position unless using global coords
		if not use_global_coords:
			pos += entity._spawn_position
		_waypoints.append(pos)
		dist += waypoint_spacing

## emit move_to for the current waypoint, advance on arrival
func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty():
		return
	
	var target := _waypoints[_current_index]
	var to_target = target - entity.global_position
	
	entity.blackboard[move_key] = to_target.normalized()
	entity.blackboard[distance_key] = to_target.length()
	
	if entity.global_position.distance_to(target) < arrival_distance:
		_advance_waypoint()

## move to next waypoint, handle end-of-path based on patrol_mode
func _advance_waypoint() -> void:
	if _direction > 0:
		_current_index += 1
		if _current_index >= _waypoints.size():
			match patrol_mode:
				CDEnums.PatrolMode.LOOP:
					_current_index = 0
				CDEnums.PatrolMode.RETRACE:
					_current_index = _waypoints.size() - 1
					_direction = -1
				CDEnums.PatrolMode.ONCE:
					for sig in complete_signals:
						entity.bus_emit(sig)
					set_physics_process(false)
	else:
		_current_index -= 1
		if _current_index < 0:
			match patrol_mode:
				CDEnums.PatrolMode.LOOP:
					_current_index = 0
				CDEnums.PatrolMode.RETRACE:
					_current_index = 0
					_direction = 1
				CDEnums.PatrolMode.ONCE:
					for sig in complete_signals:
						entity.bus_emit(sig)
					set_physics_process(false)

## Reset the waypoint index and traversal direction on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_index = 0
	_direction = 1
