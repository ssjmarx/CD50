# FormationDirector
# Manages a grid of named slots for formation entities (Galaga-style)
# Auto-assigns group members to slots, animates breathing
# Writes move_direction + move_distance to entity blackboard each frame

@tool
class_name FormationDirector extends CDGameComponent

# --- exports ---

# groups containing entities that should occupy formation slots
@export var formation_groups: Array[StringName] = [&"formation"]
# true = entity must be in ALL groups; false = entity must be in ANY group
@export var require_all: bool = false

# grid dimensions
@export var columns: int = 10
@export var rows: int = 5

# size of each grid cell
@export var cell_size: Vector2 = Vector2(16, 16)
# spacing between cells (base spacing, scaled by breathing)
@export var cell_spacing: Vector2 = Vector2(4, 4)

# fill direction for slot assignment priority:
@export var fill_direction: Vector2 = Vector2.ZERO

# breathing animation: uniformly scales cell_spacing over time
@export_group("Breathing")
# amplitude of spacing scale (0 = no breathing, 1.0 = spacing doubles at peak)
@export var breathing_amplitude: float = 0.0
# duration in seconds for one full breathe-in/breathe-out cycle
@export var breathing_duration: float = 4.0

@export_group("Blackboard Keys")
# key for writing movement direction to entity blackboard (Vector2)
@export var direction_key: StringName = &"move_direction"
# key for writing remaining distance to entity blackboard (float)
@export var distance_key: StringName = &"move_distance"

# editor preview drawing settings
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

# --- state ---

# flat array of slot contents (null = empty, CDEntity = occupied)
var _slots: Array = []
# current phase for breathing animation
var _breathing_phase: float = 0.0
# entities assigned this frame (prevents stale cleanup from removing them)
var _assigned_this_frame: Dictionary = {}

# --- lifecycle ---

# initialize slots array
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	_init_slots()

# --- editor preview ---

# animate breathing in editor for preview
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if breathing_amplitude > 0.0:
		_advance_breathing(delta)
		queue_redraw()

# draw a circle at each slot center
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	for i in columns * rows:
		var pos := _calculate_slot_position_local(i)
		draw_circle(pos, preview_radius, preview_color)

# --- processing ---

# advance breathing, clean stale slots, write move data to entity blackboards
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# advance breathing
	_advance_breathing(delta)
	
	# auto-assign untracked group members to empty slots
	_auto_assign_slots()
	
	# clean stale slots (invalid or left groups)
	for i in _slots.size():
		var slot = _slots[i]
		if slot == null:
			continue
		if not is_instance_valid(slot):
			_slots[i] = null
			continue
		var slot_entity: CDEntity = slot
		if _assigned_this_frame.has(slot_entity):
			continue
		if not _is_in_formation_groups(slot_entity):
			_slots[i] = null
	
	# write move_direction + move_distance to entity blackboards
	for i in _slots.size():
		var slot = _slots[i]
		if slot == null:
			continue
		if not is_instance_valid(slot):
			_slots[i] = null
			continue
		var slot_entity: CDEntity = slot
		if slot_entity.state != CDEnums.EntityState.ACTIVE:
			continue
		
		var target := _calculate_slot_position(i)
		var distance := slot_entity.global_position.distance_to(target)
		
		# write direction and distance for positional legs
		if distance > 0.001:
			slot_entity.blackboard[direction_key] = slot_entity.global_position.direction_to(target)
			slot_entity.blackboard[distance_key] = distance
		else:
			slot_entity.blackboard[distance_key] = 0.0
	
	_assigned_this_frame.clear()

# --- breathing ---

# advance the breathing phase
func _advance_breathing(delta: float) -> void:
	if breathing_duration > 0.0:
		_breathing_phase += delta / breathing_duration * TAU

# get the current breathing scale factor (1.0 = minimum/configured, >1.0 = expanded)
func _get_breathing_scale() -> float:
	return 1.0 + abs(sin(_breathing_phase)) * breathing_amplitude

# --- slot management ---

# find the best empty slot based on fill_direction priority
func _find_empty_slot() -> int:
	var best_index := -1
	var best_score := INF
	
	for i in _slots.size():
		if _slots[i] != null:
			continue
		var pos := _calculate_slot_position_local(i)
		var score: float
		if fill_direction == Vector2.ZERO:
			score = pos.length()  # center-out: prefer slots closest to center
		else:
			score = -pos.dot(fill_direction)  # directional: prefer side fill_direction points to
		if score < best_score:
			best_score = score
			best_index = i
	
	return best_index

# calculate world position for a slot index (grid + breathing scale)
func _calculate_slot_position(slot_index: int) -> Vector2:
	return global_position + _calculate_slot_position_local(slot_index)

# calculate local position for a slot index (used by both runtime and editor preview)
func _calculate_slot_position_local(slot_index: int) -> Vector2:
	@warning_ignore("integer_division")
	var col := slot_index % columns
	@warning_ignore("integer_division")
	var row := slot_index / columns
	
	# apply breathing scale to spacing
	var breathing_scale := _get_breathing_scale()
	var scaled_spacing := cell_spacing * breathing_scale
	
	# grid layout with scaled spacing
	var step_x := cell_size.x + scaled_spacing.x
	var step_y := cell_size.y + scaled_spacing.y
	var grid_width := columns * step_x - scaled_spacing.x
	var grid_height := rows * step_y - scaled_spacing.y
	
	# position centered on director
	var x := col * step_x - grid_width * 0.5 + cell_size.x * 0.5
	var y := row * step_y - grid_height * 0.5 + cell_size.y * 0.5
	
	return Vector2(x, y)

# auto-detect untracked group members and assign them to empty slots
func _auto_assign_slots() -> void:
	var entities := _gather_formation_entities()
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if entity in _slots:
			continue
		
		var slot_index := _find_empty_slot()
		if slot_index == -1:
			push_warning("FormationDirector '%s': no empty slots for '%s'." % [name, entity.name])
			continue
		
		_slots[slot_index] = entity
		_assigned_this_frame[entity] = true

# gather entities from all formation groups (deduplicated)
func _gather_formation_entities() -> Array[CDEntity]:
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []
	for group_name in formation_groups:
		for entity in game.group_registry.get_group(group_name):
			if not seen.has(entity):
				seen[entity] = true
				result.append(entity)
	return result

# check if entity is a member of the formation groups (per require_all mode)
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

# --- reset ---

# clear all slots and animation state for game restart
func reset() -> void:
	_init_slots()
	_breathing_phase = 0.0
	_assigned_this_frame.clear()

# initialize the slot array with null entries
func _init_slots() -> void:
	_slots.clear()
	_slots.resize(columns * rows)
	for i in _slots.size():
		_slots[i] = null