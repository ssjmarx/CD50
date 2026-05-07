# Swarm controller. Drives Bug Blaster-style group movement with tick-based
# horizontal stepping, edge detection, step-down shifts, and speed ramping.
#
# State machine: MOVING → (edge hit) → STEP_DOWN → MOVING
# All movement happens on tick boundaries only — no deferred execution.

extends UniversalComponent2D

enum State { MOVING, STEP_DOWN }

enum BottomAction { NONE, DEFEAT, LOSE_LIFE, VICTORY }

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
@export var bottom_action: BottomAction = BottomAction.NONE
@export var wave_speed_decrease: float = 0.0

# Emitted each tick to move all swarm members in a direction
signal swarm_move(direction: Vector2)
# Emitted when any swarm member reaches the bottom boundary
signal swarm_at_bottom

# Runtime state
var _tick_timer: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _state: State = State.MOVING
var _total_members: int = 0
var _prev_living: int = 0
var _bottom_triggered: bool = false
var _wave_count: int = 0

# Join bus group; wait one frame for scene tree to settle
func _ready() -> void:
	add_to_group(bus_group)
	GroupCache.mark_dirty(bus_group)
	await get_tree().process_frame

# Tick the swarm forward at the current interval; auto-reset on new wave
func _physics_process(delta: float) -> void:
	_tick_timer += delta
	var interval = _get_current_interval()
	
	if _tick_timer >= interval:
		_tick_timer = 0.0
		_execute_tick()

# Calculate tick interval, ramping speed as invaders are destroyed.
# Tracks peak group size so speed ramp works even with staggered spawning.
# Auto-resets when a new wave appears (group transitions from empty).
func _get_current_interval() -> float:
	var living = get_group_count(invader_group)
	
	# Detect new wave: invaders appeared after group was empty
	if living > 0 and _prev_living == 0:
		reset_wave()
	_prev_living = living
	
	var effective_base = _get_effective_base_interval()
	if not speed_ramp_enabled:
		return effective_base
	if living == 0:
		return effective_base
	_total_members = max(_total_members, living)
	if _total_members == living:
		return effective_base
	var ratio = float(living) / float(_total_members)
	var interval = effective_base * ratio
	return maxf(interval, min_tick_interval)

# Execute one tick: move horizontally or step down, based on current state
func _execute_tick() -> void:
	match _state:
		State.MOVING:
			swarm_move.emit(_direction)
			if _is_at_edge():
				_state = State.STEP_DOWN
		
		State.STEP_DOWN:
			for i in range(step_down_distance):
				swarm_move.emit(Vector2.DOWN)
			if not _bottom_triggered and _is_at_bottom():
				swarm_at_bottom.emit()
				_handle_bottom_action()
				_bottom_triggered = true
			_direction = -_direction
			_state = State.MOVING

# Trigger the configured action when invaders reach the bottom boundary
func _handle_bottom_action() -> void:
	match bottom_action:
		BottomAction.DEFEAT:
			game.defeat.emit()
		BottomAction.LOSE_LIFE:
			game.get_node("LivesCounter").lose_life()
		BottomAction.VICTORY:
			game.victory.emit()

# Reset runtime state for a new wave (direction, timer, speed ramp baseline)
func reset_wave() -> void:
	_wave_count += 1
	_direction = Vector2.RIGHT
	_state = State.MOVING
	_tick_timer = 0.0
	_total_members = 0
	_bottom_triggered = false

# Get the effective base interval, accounting for per-wave speed increase
func _get_effective_base_interval() -> float:
	var effective = base_tick_interval - (_wave_count - 1) * wave_speed_decrease
	return maxf(effective, min_tick_interval)

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