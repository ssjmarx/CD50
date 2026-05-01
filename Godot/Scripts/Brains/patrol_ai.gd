# AI brain that follows a path of baked waypoints. Supports looping, retracing, and random path generation.

extends UniversalComponent

# Path configuration
@export var curve: Curve2D
@export var look_ahead_distance: float = 20.0
@export var waypoint_count: int = 3
@export var loop_mode: LoopMode = LoopMode.NONE
@export var margin: float = 100.0

enum LoopMode { 
	NONE, 
	RESTART, 
	RETRACE 
	}

# Runtime state
var direction: int = 1
var current_index: int = 0
var baked_points: PackedVector2Array = []
var _needs_path: bool = false

# Load baked points from curve, or flag for random path generation
func _ready() -> void:
	if curve != null:
		baked_points = curve.get_baked_points()
	else:
		_needs_path = true

# Move toward the current waypoint and advance when within look_ahead_distance
func _physics_process(_delta: float) -> void:
	if _needs_path:
		baked_points = _generate_random_path().get_baked_points()
		_needs_path = false
	var target_point: Vector2 = baked_points[current_index]
	var distance: float = parent.global_position.distance_to(target_point)

	if distance < look_ahead_distance:
		current_index += direction
		if current_index >= baked_points.size() or current_index < 0:
			match loop_mode:
				LoopMode.NONE: 
					parent.move.emit(Vector2.ZERO)
					set_physics_process(false)
					return
				LoopMode.RESTART: 
					current_index = 0
				LoopMode.RETRACE:
					direction *= -1
					current_index += direction
	
	target_point = baked_points[current_index]
	parent.move.emit(parent.global_position.direction_to(target_point))

# Build a random path from the parent's position through random waypoints to a screen edge
func _generate_random_path() -> Curve2D:
	curve = Curve2D.new()

	var viewport: Rect2 = get_viewport().get_visible_rect()
	var w: float = viewport.size.x
	var h: float = viewport.size.y

	var end_edge: int = randi() % 4
	
	var start_pos: Vector2 = parent.global_position
	start_pos.x = clampf(start_pos.x, parent.x_min, parent.x_max)
	start_pos.y = clampf(start_pos.y, parent.y_min, parent.y_max)
	curve.add_point(start_pos)

	for i: int in range(waypoint_count - 2):
		curve.add_point(Vector2(randf_range(0 + margin, w - margin), randf_range(0 + margin, h - margin)))

	curve.add_point(_point_on_edge(end_edge, w, h))

	return curve

# Return a random point on the specified screen edge
func _point_on_edge(edge: int, w: float, h: float) -> Vector2:
	match edge:
		0: return Vector2(-margin, randf_range(0, h))
		1: return Vector2(w + margin, randf_range(0, h))
		2: return Vector2(randf_range(0, w), -margin)
		3: return Vector2(randf_range(0, w), h + margin)
	return Vector2.ZERO