## GridMovementLeg
## Moves entity by a fixed grid step, one step per hop_delay interval
## Uses edge detection on blackboard direction to capture discrete inputs into a queue
## If continuous distance is provided, chops it into discrete steps automatically

class_name GridMovementLeg extends CDEntityComponent

## --- exports ---

## size of each grid cell in pixels
@export var cell_size: Vector2 = Vector2(16, 16)
## whether to check for occupied cells before moving
@export var check_collision: bool = true
## seconds between queue drains (0 = every frame, for non-Tetris grid games)
@export var hop_delay: float = 0.0
## maximum buffered inputs (0 = no buffering, instant execution only)
@export var max_queue_size: int = 4
## whether diagonal directions are allowed
@export var allow_diagonal: bool = false

@export_group("Blackboard Keys")
## key to read movement direction from (Vector2)
@export var direction_key: StringName = &"move_direction"
## key to read continuous movement distance/speed from (float). If present, enables continuous stepping.
@export var distance_key: StringName = &"move_distance"
## key written after a successful step (Vector2), for sibling components
@export var step_direction_key: StringName = &"step_direction"

@export_group("Emit Signals")
## emitted when a step is blocked by collision (zero-arg)
@export var step_blocked_signals: Array[StringName] = [&"step_blocked"]
## emitted when a step is successfully taken (zero-arg)
@export var step_taken_signals: Array[StringName] = [&"step_taken"]

## --- state ---

## internal input buffer
var _input_queue: Array[Vector2i] = []
## previous frame's direction for edge detection
var _prev_direction: Vector2 = Vector2.ZERO
## hop delay accumulator
var _hop_timer: float = 0.0
## continuous movement accumulator (chops continuous intent into discrete steps)
var _accumulated_step_distance: float = 0.0

## --- lifecycle ---

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## --- processing ---

## physics process
func _physics_process(delta: float) -> void:
	if not entity:
		return
	
	var direction: Vector2 = entity.blackboard.get(direction_key, Vector2.ZERO)
	var continuous_dist: float = entity.blackboard.get(distance_key, -1.0)
	
	if continuous_dist >= 0.0:
		_process_continuous_move(direction, continuous_dist)
	else:
		_process_discrete_move(direction, delta)
		
	_prev_direction = direction

## --- movement modes ---

## process continuous movement intent (e.g. MarchingOrderDirector), chopping it into discrete grid steps
func _process_continuous_move(direction: Vector2, distance: float) -> void:
	if direction == Vector2.ZERO or distance <= 0.0:
		_accumulated_step_distance = 0.0
		return
		
	_accumulated_step_distance += distance
	
	var step_size := cell_size.x
	if absf(direction.y) > absf(direction.x):
		step_size = cell_size.y
		
	# We might need to step multiple times if distance is huge (frame lag)
	while _accumulated_step_distance >= step_size:
		_accumulated_step_distance -= step_size
		var step := _direction_to_step(direction)
		# We bypass the input queue for continuous movement to avoid desync/buffering
		if not _try_step(step):
			# If blocked, reset accumulator to prevent spamming blocked signals or queueing up massive offsets
			_accumulated_step_distance = 0.0
			break

## process discrete input (e.g. button presses) via edge detection and queue
func _process_discrete_move(direction: Vector2, delta: float) -> void:
	## 1. edge detection — capture new discrete inputs
	if direction != _prev_direction and direction != Vector2.ZERO:
		var step := _direction_to_step(direction)
		if step != Vector2i.ZERO:
			if max_queue_size > 0:
				if _input_queue.size() < max_queue_size:
					_input_queue.append(step)
			else:
				_try_step(step)
	
	if _input_queue.is_empty():
		return
	
	if hop_delay <= 0.0:
		_drain_queue()
	else:
		_hop_timer += delta
		if _hop_timer >= hop_delay:
			_hop_timer = 0.0
			_drain_queue()

## --- queue ---

## execute the first valid step from the input queue
func _drain_queue() -> void:
	while not _input_queue.is_empty():
		var step: Vector2i = _input_queue.pop_front()
		if _try_step(step):
			return

## --- step execution ---

## attempt to move one cell in the given step direction, return true if successful
func _try_step(step: Vector2i) -> bool:
	var displacement := Vector2(step) * cell_size
	var target_pos := entity.global_position + displacement
	
	## check if target cell is blocked
	if check_collision and _is_occupied(target_pos):
		for sig in step_blocked_signals:
			entity.bus_emit(sig)
		return false
	
	entity.request_position_add(displacement)
	
	entity.blackboard[step_direction_key] = Vector2(step)
	
	for sig in step_taken_signals:
		entity.bus_emit(sig)
		
	return true

## --- helpers ---

## convert a continuous direction vector to a discrete grid step
func _direction_to_step(dir: Vector2) -> Vector2i:
	if allow_diagonal and absf(dir.x) > 0.5 and absf(dir.y) > 0.5:
		return Vector2i(1 if dir.x > 0 else -1, 1 if dir.y > 0 else -1)
	elif absf(dir.x) > absf(dir.y):
		return Vector2i(1 if dir.x > 0 else -1, 0)
	elif absf(dir.y) > absf(dir.x):
		return Vector2i(0, 1 if dir.y > 0 else -1)
	return Vector2i.ZERO

## point-cast to check if a world position is occupied by another body
func _is_occupied(pos: Vector2) -> bool:
	var space_state := entity.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.exclude = [entity.get_rid()]
	var results := space_state.intersect_point(query)
	return results.size() > 0

## --- cleanup ---

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_input_queue.clear()
	_prev_direction = Vector2.ZERO
	_hop_timer = 0.0
	_accumulated_step_distance = 0.0
