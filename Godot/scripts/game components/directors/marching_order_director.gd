@tool
class_name MarchingOrderDirector extends CDGameComponent

## MarchingOrderDirector
## A blind conductor that translates continuous CDMarchingOrder resources
## into a continuous movement intent for target entities.
## It evaluates the path delta every frame and writes the direction/velocity 
## to entity blackboards, leaving discrete stepping logic to the Legs.

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

@export_group("Blackboard Keys")
## key for writing continuous movement direction to entity blackboard (Vector2)
@export var direction_key: StringName = &"move_direction"
## key for writing movement magnitude (speed) to entity blackboard (float)
@export var distance_key: StringName = &"move_distance"

@export_group("Listen Signals")
## when heard on the game bus, resets the marching sequence to the very beginning
@export var reset_signal: StringName = &"reset_orders"

## --- marching state ---
var _marching_index: int = -1
var _scaled_marching_timer: float = 0.0
var _accumulated_offset: Vector2 = Vector2.ZERO
var _total_marching_offset: Vector2 = Vector2.ZERO

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
		
	# Connect listen signals
	if reset_signal != &"":
		game.bus_connect(reset_signal, _on_reset_orders)

## --- processing ---

## advance marching orders and write continuous move data to entities
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if marching_orders.is_empty(): return

	# 1. Evaluate continuous offset for this frame
	var prev_offset := _total_marching_offset
	_advance_marching(delta)
	var delta_offset := _total_marching_offset - prev_offset

	# 2. Write the continuous intent to all target entities
	_write_move_data(delta_offset)

## --- marching orders logic (mirrors FormationDirector) ---

## reset state machine for marching
func _reset_marching_state() -> void:
	_marching_index = 0
	_scaled_marching_timer = 0.0
	_accumulated_offset = Vector2.ZERO
	_total_marching_offset = Vector2.ZERO

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
			
	## Scale the time slice for the current frame only.
	## This prevents retroactive time jumps when the multiplier changes mid-step.
	var scaled_delta := delta * multiplier
	_scaled_marching_timer += scaled_delta
	
	## Evaluate offset using the smoothly accumulated scaled time
	_total_marching_offset = _accumulated_offset + order.get_offset_at_time(_scaled_marching_timer)
	
	## advance to next order when scaled timer exceeds base duration
	if _scaled_marching_timer >= base_duration:
		## carry over excess scaled time to prevent micro-stutters between steps
		var excess_time := _scaled_marching_timer - base_duration
		_scaled_marching_timer = excess_time
		
		## commit the final offset to accumulator
		_accumulated_offset += order.get_accumulated_offset()
		
		_marching_index += 1
		if _marching_index >= marching_orders.size():
			_marching_index = 0  ## loop marching orders
			_accumulated_offset = Vector2.ZERO 

## --- signal handlers ---

## resets the marching sequence back to the first order
func _on_reset_orders() -> void:
	_reset_marching_state()

## --- command execution ---

## translate the delta vector into a continuous blackboard write
func _write_move_data(delta_offset: Vector2) -> void:
	var entities := _gather_target_entities()
	
	var dir: Vector2 = delta_offset.normalized()
	var dist: float = delta_offset.length()
	
	# Snap to zero to avoid floating point noise on stops
	if dist < 0.001:
		dir = Vector2.ZERO
		dist = 0.0
		
	for entity in entities:
		if not is_instance_valid(entity): continue
		if entity.state != CDEnums.EntityState.ACTIVE: continue
		
		# Write the continuous packet to the blackboard
		entity.blackboard[direction_key] = dir
		entity.blackboard[distance_key] = dist

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
