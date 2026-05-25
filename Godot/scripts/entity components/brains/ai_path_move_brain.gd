## follows a pre-defined Curve2D resource, emitting positional targets as waypoints
class_name AIPathMoveBrain extends CDEntityComponent

@export var path_curve: Curve2D
@export var waypoint_spacing: float = 20.0
@export var arrival_distance: float = 5.0

@export var patrol_mode: CDEnums.PatrolMode = CDEnums.PatrolMode.LOOP
@export var use_global_coords: bool = false

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move_to"]
@export var complete_signals: Array[StringName] = [&"patrol_complete"]

var _waypoints: Array[Vector2] = []
var _current_index: int = 0
var _direction: int = 1  # for retrace

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	for sig in complete_signals:
		entity.ensure_signal(sig)
	_build_waypoints()

func _build_waypoints() -> void:
	if not path_curve or path_curve.point_count < 2:
		return
	_waypoints.clear()
	var total_length := path_curve.get_baked_length()
	var dist := 0.0
	while dist <= total_length:
		var pos := path_curve.sample_baked(dist)
		if not use_global_coords:
			pos += entity._spawn_position
		_waypoints.append(pos)
		dist += waypoint_spacing

func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty():
		return
	
	var target := _waypoints[_current_index]
	
	for sig in move_signals:
		entity.emit_signal(sig, target)
	
	if entity.global_position.distance_to(target) < arrival_distance:
		_advance_waypoint()

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
