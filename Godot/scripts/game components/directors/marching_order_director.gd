@tool
class_name MarchingOrderDirector extends CDGameComponent

## MarchingOrderDirector
## A blind conductor that translates continuous CDMarchingOrder resources
## into discrete grid step commands for target entities.
## It evaluates the path, samples the movement delta, and issues discrete steps via the blackboard.

## --- exports ---

## groups containing entities that should receive the move commands
@export var target_groups: Array[StringName] = [&"enemies"]
## true = entity must be in ALL groups; false = entity must be in ANY group
@export var require_all: bool = false

## ordered movement commands — step, pause, breathe (same data as FormationDirector)
@export_group("Marching")
@export var marching_orders: Array[CDMarchingOrder] = []:
	set(v):
		marching_orders = v
		if is_node_ready():
			_reset_marching_state()

## optional scaler that multiplies marching speed (higher = faster)
@export var speed_scaler: CDScaler

@export_group("Discrete Stepping")
## The world-unit distance of a single grid step/cell
@export var step_size: float = 16.0

@export_group("Blackboard Keys")
## key for writing movement direction to entity blackboard (Vector2)
@export var direction_key: StringName = &"move_direction"
## key for writing step distance to entity blackboard (float)
@export var distance_key: StringName = &"move_distance"

## --- marching state ---
var _marching_index: int = -1
var _marching_timer: float = 0.0
var _scaled_marching_timer: float = 0.0
var _accumulated_offset: Vector2 = Vector2.ZERO
var _total_marching_offset: Vector2 = Vector2.ZERO

## --- step tracking state ---
var _accumulated_step_distance: float = 0.0
var _last_step_dir: Vector2 = Vector2.ZERO

## --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

func _on_initialize() -> void:
	super._on_initialize()
	if speed_scaler:
		speed_scaler.initialize(game)
	if not marching_orders.is_empty():
		_reset_marching_state()

## --- processing ---

## advance marching orders, sample delta, issue discrete steps
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if marching_orders.is_empty(): return

	# 1. Evaluate continuous offset for this frame
	var prev_offset := _total_marching_offset
	_advance_marching(delta)
	var delta_offset := _total_marching_offset - prev_offset

	# 2. Convert continuous offset into discrete grid steps
	if delta_offset.length() > 0.001:
		var dir := delta_offset.normalized()
		
		# Snap to dominant axis for strict grid movement (strictly horizontal or vertical)
		var step_dir := Vector2.ZERO
		if abs(dir.x) > abs(dir.y):
			step_dir = Vector2(sign(dir.x), 0)
		elif abs(dir.y) > 0:
			step_dir = Vector2(0, sign(dir.y))
			
		if step_dir == Vector2.ZERO:
			return
			
		# If direction changed, force an immediate step so movement feels responsive
		if step_dir != _last_step_dir:
			_last_step_dir = step_dir
			_accumulated_step_distance = step_size
			
		_accumulated_step_distance += delta_offset.length()
		
		# Issue discrete steps while accumulated distance exceeds step size
		# (A large delta or low framerate can issue multiple steps to catch up)
		while _accumulated_step_distance >= step_size:
			_accumulated_step_distance -= step_size
			_issue_step_command(step_dir, step_size)

## --- marching orders logic (mirrors FormationDirector) ---

## reset state machine for marching
func _reset_marching_state() -> void:
	_marching_index = 0
	_marching_timer = 0.0
	_scaled_marching_timer = 0.0
	_accumulated_offset = Vector2.ZERO
	_total_marching_offset = Vector2.ZERO
	_accumulated_step_distance = step_size # Force first step to trigger immediately
	_last_step_dir = Vector2.ZERO

## advance the current marching order and auto-cycle through the sequence
func _advance_marching(delta: float) -> void:
	if marching_orders.is_empty():
		_total_marching_offset = Vector2.ZERO
		return
	
	if _marching_index < 0 or _marching_index >= marching_orders.size():
		_reset_marching_state()
		return
	
	var order: CDMarchingOrder = marching_orders[_marching_index]
	var base_duration := order.get_duration()
	
	## Calculate speed multiplier, defaulting to 1.0 if missing or invalid
	var multiplier := 1.0
	if speed_scaler and is_instance_valid(game):
		var evaluated := speed_scaler.evaluate()
		if evaluated > 0.0:
			multiplier = evaluated
			
	## Scale the total duration inversely by speed
	var effective_duration := base_duration / multiplier
	
	_marching_timer += delta
	_scaled_marching_timer = _marching_timer * multiplier
	
	## Evaluate offset using the scaled time
	_total_marching_offset = _accumulated_offset + order.get_offset_at_time(_scaled_marching_timer)
	
	## advance to next order when raw timer exceeds effective duration
	if _marching_timer >= effective_duration:
		_marching_timer = 0.0
		_scaled_marching_timer = 0.0
		
		## commit the final offset to accumulator
		_accumulated_offset += order.get_accumulated_offset()
		
		_marching_index += 1
		if _marching_index >= marching_orders.size():
			_marching_index = 0  ## loop marching orders
			_accumulated_offset = Vector2.ZERO 

## --- command execution ---

func _issue_step_command(dir: Vector2, dist: float) -> void:
	var entities := _gather_target_entities()
	for entity in entities:
		if not is_instance_valid(entity): continue
		if entity.state != CDEnums.EntityState.ACTIVE: continue
		
		# Write the discrete packet to the blackboard
		entity.blackboard[direction_key] = dir
		entity.blackboard[distance_key] = dist
		# Emit the signal so GridMovementLeg knows a concrete step was queued
		entity.bus_emit(&"move")

## --- helpers ---

## gather entities from all target groups (deduplicated)
func _gather_target_entities() -> Array[CDEntity]:
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []
	if not is_instance_valid(game) or not is_instance_valid(game.group_registry):
		return result
		
	for group_name in target_groups:
		for entity in game.group_registry.get_group(group_name):
			if not seen.has(entity):
				seen[entity] = true
				result.append(entity)
	return result
