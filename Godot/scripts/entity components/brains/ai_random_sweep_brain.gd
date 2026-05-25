## generates a multi-waypoint sweep path across the play area
class_name AIRandomSweepBrain extends CDEntityComponent

@export var waypoint_count: int = 1
@export var waypoint_radius: float = 100.0
@export var valid_exit_edges: Array[CDEnums.Edge] = [
	CDEnums.Edge.TOP, CDEnums.Edge.BOTTOM,
	CDEnums.Edge.LEFT, CDEnums.Edge.RIGHT
]
@export var exit_overshoot: float = 50.0
@export var arrival_distance: float = 5.0
@export var patrol_mode: CDEnums.PatrolMode = CDEnums.PatrolMode.ONCE

@export_group("Emit Signals")
@export var move_signals: Array[StringName] = [&"move"]
@export var complete_signals: Array[StringName] = [&"sweep_complete"]

var _waypoints: Array[Vector2] = []
var _current_waypoint: int = 0
var _direction: float = 1.0

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

func _on_initialize() -> void:
	for sig in move_signals:
		entity.ensure_signal(sig)
	for sig in complete_signals:
		entity.ensure_signal(sig)
	_generate_waypoints()

## generate waypoints near the center of the screen
func _generate_waypoints() -> void:
	var bounds := game.game_bounds
	var center := bounds.get_center()
	_waypoints.clear()
	
	for i in range(waypoint_count):
		var angle := randf() * TAU
		var distance := randf() * waypoint_radius
		var point := center + Vector2(cos(angle), sin(angle)) * distance
		point.x = clampf(point.x, bounds.position.x, bounds.end.x)
		point.y = clampf(point.y, bounds.position.y, bounds.end.y)
		_waypoints.append(point)
	
	var exit_edge: CDEnums.Edge = valid_exit_edges.pick_random()
	var exit_point := _edge_point(exit_edge, bounds, exit_overshoot)
	_waypoints.append(exit_point)
	
	_current_waypoint = 0
	_direction = 1.0

func _edge_point(edge: CDEnums.Edge, bounds: Rect2, overshoot: float) -> Vector2:
	match edge:
		CDEnums.Edge.TOP:
			return Vector2(
				randf_range(bounds.position.x, bounds.end.x),
				bounds.position.y - overshoot
			)
		CDEnums.Edge.BOTTOM:
			return Vector2(
				randf_range(bounds.position.x, bounds.end.x),
				bounds.end.y + overshoot
			)
		CDEnums.Edge.LEFT:
			return Vector2(
				bounds.position.x - overshoot,
				randf_range(bounds.position.y, bounds.end.y)
			)
		CDEnums.Edge.RIGHT:
			return Vector2(
				bounds.end.x + overshoot,
				randf_range(bounds.position.y, bounds.end.y)
			)
	return bounds.get_center()

func _physics_process(_delta: float) -> void:
	if _waypoints.is_empty():
		return
	
	var target := _waypoints[_current_waypoint]
	var to_target := target - entity.global_position
	var distance := to_target.length()
	
	if distance > arrival_distance:
		for sig in move_signals:
			entity.emit_signal(sig, to_target.normalized())
	else:
		_advance_waypoint()

func _advance_waypoint() -> void:
	if _direction > 0.0:
		_current_waypoint += 1
		if _current_waypoint >= _waypoints.size():
			match patrol_mode:
				CDEnums.PatrolMode.LOOP:
					_current_waypoint = 0
				CDEnums.PatrolMode.RETRACE:
					_current_waypoint = _waypoints.size() - 1
					_direction = -1.0
				CDEnums.PatrolMode.ONCE:
					for sig in complete_signals:
						entity.emit_signal(sig)
					set_physics_process(false)
	else:
		_current_waypoint -= 1
		if _current_waypoint < 0:
			match patrol_mode:
				CDEnums.PatrolMode.LOOP:
					_current_waypoint = 0
				CDEnums.PatrolMode.RETRACE:
					_current_waypoint = 0
					_direction = 1.0
				CDEnums.PatrolMode.ONCE:
					for sig in complete_signals:
						entity.emit_signal(sig)
					set_physics_process(false)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_waypoints.clear()
	_current_waypoint = 0
	_direction = 1.0
