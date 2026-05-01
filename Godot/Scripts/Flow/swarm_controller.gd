# Swarm controller. Drives Space Invaders-style group movement with tick-based
# horizontal stepping, edge detection, step-down shifts, and speed ramping.

extends UniversalComponent2D

# Tick timing and speed ramp
@export var base_tick_interval: float = 1.0
@export var min_tick_interval: float = 0.1
@export var speed_ramp_enabled: bool = true
@export var step_down_distance: int = 1

# Group and boundary configuration
@export var invader_group: String = "invaders"
@export var bus_group: String = "swarm_bus"
@export var boundary_left: float = 32.0
@export var boundary_right: float = 608.0
@export var boundary_bottom: float = 340.0

# Emitted each tick to move all swarm members in a direction
signal swarm_move(direction: Vector2)
# Emitted when any swarm member reaches the bottom boundary
signal swarm_at_bottom

# Runtime state
var _tick_timer: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _pending_step_down: bool = false
var _total_members: int = 0

# Join bus group and count initial swarm members
func _ready() -> void:
	add_to_group(bus_group)
	await get_tree().process_frame
	_total_members = get_group_count(invader_group)

# Tick the swarm forward at the current interval; handle pending step-downs
func _physics_process(delta: float) -> void:
	_tick_timer += delta
	var interval = _get_current_interval()
	
	if _tick_timer >= interval:
		_tick_timer = 0.0
		_execute_tick()
	
	# Execute deferred step-down after horizontal tick
	if _pending_step_down:
		for i in range(step_down_distance):
			swarm_move.emit(Vector2.DOWN)
		if _is_at_bottom():
			swarm_at_bottom.emit()
		_direction = -_direction
		_pending_step_down = false

# Calculate tick interval, ramping speed as invaders are destroyed
func _get_current_interval() -> float:
	if not speed_ramp_enabled:
		return base_tick_interval
	var living = get_group_count(invader_group)
	if _total_members == 0:
		return base_tick_interval
	var ratio = float(living) / float(_total_members)
	var interval = base_tick_interval * ratio
	return maxf(interval, min_tick_interval)

# Emit a move signal; queue step-down if at screen edge
func _execute_tick() -> void:
	if _pending_step_down:
		swarm_move.emit(Vector2.DOWN)
		_direction = -_direction 
		_pending_step_down = false
	else:
		swarm_move.emit(_direction)
		if _is_at_edge():
			_pending_step_down = true

# Check if any swarm member has reached the left or right boundary
func _is_at_edge() -> bool:
	for member in get_group_nodes(invader_group):
		if _direction.x > 0 and member.global_position.x >= boundary_right:
			return true
		if _direction.x < 0 and member.global_position.x <= boundary_left:
			return true
	return false

# Check if any swarm member has reached the bottom boundary
func _is_at_bottom() -> bool:
	for member in get_group_nodes(invader_group):
		if member.global_position.y >= boundary_bottom:
			return true
	return false
