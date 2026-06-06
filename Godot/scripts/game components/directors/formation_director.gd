## FormationDirector
## Manages multiple sub-formation grids (CDFormation) for tiered enemy placement
## Auto-assigns group members to slots, animates breathing, writes move data to entity blackboards

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

## continuous breathing animation (used when no marching orders are assigned)
@export_group("Breathing")
## amplitude of spacing scale (0 = no breathing, 1.0 = spacing doubles at peak)
@export var breathing_amplitude: float = 0.0
## duration in seconds for one full breathe-in/breathe-out cycle
@export var breathing_duration: float = 4.0

## ordered movement commands — step, breathe, pause
@export_group("Marching")
@export var marching_orders: Array[CDMarchingOrder] = []
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

## current phase for breathing animation
var _breathing_phase: float = 0.0
## entities assigned this frame (prevents stale cleanup from removing them)
var _assigned_this_frame: Dictionary = {}

## --- marching state ---

## current marching order index (-1 = not marching)
var _marching_index: int = -1
## time elapsed on current marching order
var _marching_timer: float = 0.0
## accumulated offset from step orders
var _marching_offset: Vector2 = Vector2.ZERO
## override breathing scale from breathe orders (<= 0 = use continuous breathing)
var _marching_breath_scale: float = -1.0

## --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()
	_init_all_slots()

## --- editor preview ---

## animate breathing in editor for preview
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if breathing_amplitude > 0.0:
		_advance_breathing(delta)
		queue_redraw()

## draw a circle at each slot center for each sub-formation
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var breathing_scale := _get_breathing_scale()
	for formation in formations:
		for i in formation.columns * formation.rows:
			var pos := formation.get_slot_position_local(i, breathing_scale)
			draw_circle(pos, preview_radius, preview_color)

## --- processing ---

## advance marching orders, breathing, clean stale slots, write move data
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_advance_marching(delta)
	_advance_breathing(delta)
	_auto_assign_slots()
	_clean_stale_slots()
	_write_move_data()
	_assigned_this_frame.clear()

## --- breathing ---

func _advance_breathing(delta: float) -> void:
	if breathing_duration > 0.0:
		_breathing_phase += delta / breathing_duration * TAU

func _get_breathing_scale() -> float:
	## marching breathe orders override continuous breathing
	if _marching_breath_scale > 0.0:
		return _marching_breath_scale
	return 1.0 + abs(sin(_breathing_phase)) * breathing_amplitude

## --- marching orders ---

## start marching on initialize
func _on_initialize() -> void:
	if speed_scaler:
		speed_scaler.initialize(game)
	if not marching_orders.is_empty():
		_marching_index = 0
		_marching_timer = 0.0

## advance the current marching order and auto-cycle through the sequence
func _advance_marching(delta: float) -> void:
	if marching_orders.is_empty() or _marching_index < 0:
		return
	
	var order: CDMarchingOrder = marching_orders[_marching_index]
	var effective_duration := order.duration
	if order.type == CDMarchingOrder.Type.STEP and order.speed_scaler:
		effective_duration = order.speed_scaler.evaluate()
	
	## apply global speed multiplier (divides duration → faster marching)
	if speed_scaler:
		var multiplier := speed_scaler.evaluate()
		if multiplier > 0.0:
			effective_duration /= multiplier
	
	_marching_timer += delta
	
	match order.type:
		CDMarchingOrder.Type.STEP:
			_marching_breath_scale = -1.0
			## apply continuous offset during the step duration
			if effective_duration > 0.0:
				_marching_offset.x += order.distance * (delta / effective_duration)
		
		CDMarchingOrder.Type.BREATHE:
			## compute breathing scale based on phase within the breathe order
			var total_time := order.expand_time + order.hold_time + order.contract_time
			if total_time > 0.0:
				var t := _marching_timer / effective_duration
				t = fmod(t, 1.0)
				if t < order.expand_time / total_time:
					_marching_breath_scale = 1.0 + order.amplitude * (t * total_time / order.expand_time)
				elif t < (order.expand_time + order.hold_time) / total_time:
					_marching_breath_scale = 1.0 + order.amplitude
				else:
					var contract_t := (t * total_time - order.expand_time - order.hold_time) / order.contract_time
					_marching_breath_scale = 1.0 + order.amplitude * (1.0 - contract_t)
		
		CDMarchingOrder.Type.PAUSE:
			_marching_breath_scale = -1.0
	
	## advance to next order when timer exceeds duration
	if _marching_timer >= effective_duration:
		_marching_timer = 0.0
		_marching_index += 1
		if _marching_index >= marching_orders.size():
			_marching_index = 0  ## loop marching orders

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
func _write_move_data() -> void:
	var breathing_scale := _get_breathing_scale()
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
			
			var target := formation.get_slot_position(i, global_position + _marching_offset, breathing_scale)
			var distance := slot_entity.global_position.distance_to(target)
			
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

## gather entities from all formation groups (deduplicated)
func _gather_formation_entities() -> Array[CDEntity]:
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []
	for group_name in formation_groups:
		for entity in game.group_registry.get_group(group_name):
			if not seen.has(entity):
				seen[entity] = true
				result.append(entity)
	return result

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
	_breathing_phase = 0.0
	_assigned_this_frame.clear()
	_marching_index = -1
	_marching_timer = 0.0
	_marching_offset = Vector2.ZERO
	_marching_breath_scale = -1.0
