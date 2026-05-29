# AIPathMoveBrain
# Follows a pre-defined Curve2D resource, emitting positional targets as waypoints
# Supports patrol modes: LOOP, RETRACE, and ONCE

class_name AIPathMoveBrain extends CDEntityComponent

# the curve resource to follow
@export var path_curve: Curve2D

# spacing between baked waypoints along the curve
@export var waypoint_spacing: float = 20.0

# distance to consider a waypoint reached
@export var arrival_distance: float = 5.0

# how to behave when the path ends
@export var patrol_mode: CDEnums.PatrolMode = CDEnums.PatrolMode.LOOP

# if false, offset waypoints by entity's spawn position
@export var use_global_coords: bool = false

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]
@export var complete_signals: Array[StringName] = [&"patrol_complete"]

# baked waypoint positions
var _waypoints: Array[Vector2] = []

# current waypoint index
var _current_index: int = 0

# traversal direction (+1 forward, -1 reverse for RETRACE)
var _direction: int = 1

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# ensure signals exist and bake waypoints from the curve
func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	for sig in complete_signals:
		entity.ensure_signal(sig)
	_build_waypoints()

# sample the curve at regular intervals to build waypoint array
func _build_waypoints() -> void:
	if not path_curve or path_curve.point_count < 2:
		return
	_waypoints.clear()
	var total_length := path_curve.get_baked_length()
	var dist := 0.0
	while dist <= total_length:
		var pos := path_curve.sample_baked(dist)
		# offset by spawn position unless using global coords
		if not use_global_coords:
			pos += entity._spawn_position
		_waypoints.append(pos)
		dist += waypoint_spacing

# emit move_to for the current waypoint, advance on arrival
func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty():
		return
	
	var target := _waypoints[_current_index]
	
	for sig in move_signals:
		entity.emit_signal(sig, target)
	
	# check if close enough to advance
	if entity.global_position.distance_to(target) < arrival_distance:
		_advance_waypoint()

# move to next waypoint, handle end-of-path based on patrol_mode
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
						entity.emit_signal(sig)
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
						entity.emit_signal(sig)
					set_physics_process(false)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_current_index = 0
	_direction = 1