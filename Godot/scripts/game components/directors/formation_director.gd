## FormationDirector
## Manages multiple sub-formation grids (CDFormation) for tiered enemy placement
## Auto-assigns group members to slots, animates breathing, writes move data to entity blackboards
## Supports data-driven marching orders (Step, Pause, Breathe) with editor preview

@tool
class_name FormationDirector extends CDGameComponent

## --- exports ---

## groups containing entities that should occupy formation slots
@export var formation_groups: Array[StringName] = [&"formation"]
## true = entity must be in ALL groups; false = entity must be in ANY group
@export var require_all: bool = false

## sub-formation definitions — each has its own grid, group preference, and offset
@export var formations: Array[CDFormation] = []:
	set(v):
		formations = v
		if is_node_ready():
			_init_all_slots()
			queue_redraw()

## ordered movement commands — step, pause, breathe
@export_group("Marching")
@export var marching_orders: Array[CDMarchingOrder] = []:
	set(v):
		marching_orders = v
		if is_node_ready():
			_reset_marching_state()
			queue_redraw()

## optional scaler that multiplies marching speed (higher = faster, divides effective duration)
@export var speed_scaler: CDScaler

@export_group("Blackboard Keys")
## key for writing movement direction to entity blackboard (Vector2)
@export var direction_key: StringName = &"move_direction"
## key for writing remaining distance to entity blackboard (float)
@export var distance_key: StringName = &"move_distance"

## editor preview drawing settings
@export_group("Preview")
@export var preview_color: Color = Color.CYAN:
	set(v):
		preview_color = v
		if is_node_ready():
			queue_redraw()
@export var preview_radius: float = 3.0:
	set(v):
		preview_radius = v
		if is_node_ready():
			queue_redraw()

## --- state ---

## entities assigned this frame (prevents stale cleanup from removing them)
var _assigned_this_frame: Dictionary = {}

## --- marching state ---

## current marching order index (-1 = not marching)
var _marching_index: int = -1
## time elapsed on current marching order (raw delta time)
var _marching_timer: float = 0.0
## time elapsed scaled by speed multiplier (used for curve evaluations)
var _scaled_marching_timer: float = 0.0
## accumulated offset from completed step orders
var _accumulated_offset: Vector2 = Vector2.ZERO
## total current offset (accumulated + active order progress) applied to formation
var _total_marching_offset: Vector2 = Vector2.ZERO

## --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()
	_init_all_slots()

## --- editor preview ---

## animate marching orders in editor for preview
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	
	if not marching_orders.is_empty():
		_advance_marching(delta)
		
	queue_redraw()

## draw formation slots at their current animated positions
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var breathing_data: Dictionary = _get_current_breathing_data()
	var breathing_scale: float = breathing_data["spacing_scale"]
	var offset_scale: float = breathing_data["offset_scale"]
	
	for formation in formations:
		for i in formation.columns * formation.rows:
			## Calculate base origin including marching offset.
			## Note: _draw operates in local space, so we do not add global_position here.
			## _total_marching_offset is a displacement vector, valid in both local and global space.
			var base_origin_local: Vector2 = _total_marching_offset
			var formation_center_offset: Vector2 = formation.offset * offset_scale
			var origin_local: Vector2 = base_origin_local + formation_center_offset
			
			var pos: Vector2 = formation.get_slot_position_local(i, breathing_scale)
			## Apply the origin to the slot position
			pos += origin_local
			draw_circle(pos, preview_radius, preview_color)

## --- processing ---

## advance marching orders, clean stale slots, write move data
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_advance_marching(delta)
	_auto_assign_slots()
	_clean_stale_slots()
	
	var breathing_data_physics: Dictionary = _get_current_breathing_data()
	_write_move_data(breathing_data_physics["spacing_scale"], breathing_data_physics["offset_scale"])
	
	_assigned_this_frame.clear()

## --- marching orders ---

## start marching on initialize
func _on_initialize() -> void:
	if speed_scaler:
		speed_scaler.initialize(game)
	if not marching_orders.is_empty():
		_reset_marching_state()

## reset state machine for marching
func _reset_marching_state() -> void:
	_marching_index = 0
	_marching_timer = 0.0
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
			_accumulated_offset = Vector2.ZERO ## reset loop to keep positions bounded or keep accumulating? 
			## For looping patterns like Galaga, we usually want to return to start or repeat from current. 
			## Resetting accumulator forces the pattern to snap back to start. 
			## Comment out the line below to allow endless drifting.
			_accumulated_offset = Vector2.ZERO 

## --- breathing helpers ---

## fetch breathing data from the current marching order, if supported
func _get_current_breathing_data() -> Dictionary:
	if _marching_index >= 0 and _marching_index < marching_orders.size():
		var order: CDMarchingOrder = marching_orders[_marching_index]
		## Use scaled timer so breathing matches the scaled movement speed
		return order.get_breathing_values(_scaled_marching_timer)
	
	## default to no breathing
	return { "spacing_scale": 1.0, "offset_scale": 1.0 }

## --- slot management ---

## initialize all sub-formation slot arrays
func _init_all_slots() -> void:
	for formation in formations:
		formation.init_slots()

## auto-detect untracked group members and assign them to preferred formation slots
func _auto_assign_slots() -> void:
	var entities := _gather_formation_entities()
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if _is_entity_in_any_slot(entity):
			continue
		
		# first try preferred group formations
		var assigned := false
		for formation in formations:
			if formation.preferred_group != &"" and entity.is_in_group(formation.preferred_group):
				var slot_index := formation.find_empty_slot()
				if slot_index != -1:
					formation.slots[slot_index] = entity
					_assigned_this_frame[entity] = true
					assigned = true
					break
		
		if assigned:
			continue
		
		# fallback: any formation with empty slots (prefer formations without preferred_group)
		for formation in formations:
			if formation.preferred_group == &"":
				var slot_index := formation.find_empty_slot()
				if slot_index != -1:
					formation.slots[slot_index] = entity
					_assigned_this_frame[entity] = true
					assigned = true
					break
		
		if assigned:
			continue
		
		# last resort: preferred group formations that are full but have empty slots from other groups
		for formation in formations:
			var slot_index := formation.find_empty_slot()
			if slot_index != -1:
				formation.slots[slot_index] = entity
				_assigned_this_frame[entity] = true
				break

## remove invalid or out-of-group entities from all slots
func _clean_stale_slots() -> void:
	for formation in formations:
		for i in formation.slots.size():
			var slot = formation.slots[i]
			if slot == null:
				continue
			if not is_instance_valid(slot):
				formation.slots[i] = null
				continue
			var slot_entity: CDEntity = slot
			if _assigned_this_frame.has(slot_entity):
				continue
			if not _is_in_formation_groups(slot_entity):
				formation.slots[i] = null

## write move_direction + move_distance to entity blackboards
func _write_move_data(spacing_scale: float, offset_scale: float) -> void:
	for formation in formations:
		for i in formation.slots.size():
			var slot = formation.slots[i]
			if slot == null:
				continue
			if not is_instance_valid(slot):
				formation.slots[i] = null
				continue
			var slot_entity: CDEntity = slot
			if slot_entity.state != CDEnums.EntityState.ACTIVE:
				continue
			
			var base_origin: Vector2 = global_position + _total_marching_offset
			var formation_center_offset: Vector2 = formation.offset * offset_scale
			var target: Vector2 = formation.get_slot_position(i, base_origin + formation_center_offset, spacing_scale)
			
			var distance: float = slot_entity.global_position.distance_to(target)
			
			if distance > 0.001:
				slot_entity.blackboard[direction_key] = slot_entity.global_position.direction_to(target)
				slot_entity.blackboard[distance_key] = distance
			else:
				slot_entity.blackboard[distance_key] = 0.0

## check if an entity is already tracked in any formation's slots
func _is_entity_in_any_slot(entity: CDEntity) -> bool:
	for formation in formations:
		if entity in formation.slots:
			return true
	return false

## gather entities from all formation groups (deduplicated; active filtering
## happens later in _auto_assign_slots)
func _gather_formation_entities() -> Array[CDEntity]:
	return game.group_registry.get_groups_union(formation_groups, false)

## check if entity is a member of the formation groups (per require_all mode)
func _is_in_formation_groups(entity: CDEntity) -> bool:
	if formation_groups.is_empty():
		return false
	
	if require_all:
		for group_name in formation_groups:
			if not entity.is_in_group(group_name):
				return false
		return true
	else:
		for group_name in formation_groups:
			if entity.is_in_group(group_name):
				return true
		return false

## --- reset ---

## clear all slots and animation state for game restart
func reset() -> void:
	if speed_scaler:
		speed_scaler.reset()
	_init_all_slots()
	_assigned_this_frame.clear()
	_reset_marching_state()
