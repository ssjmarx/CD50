# FormationDirector
# Manages a grid of named slots for formation entities (Galaga-style)
# Auto-assigns group members to slots, animates breathing/stepping, commands move_to each frame

class_name FormationDirector extends CDGameComponent

# --- exports ---

# group name for entities that should occupy formation slots
@export var formation_group: StringName = &"formation"
# grid dimensions
@export var columns: int = 10
@export var rows: int = 5
# size of each grid cell
@export var cell_size: Vector2 = Vector2(16, 16)
# spacing between cells
@export var cell_spacing: Vector2 = Vector2(4, 4)
# sinusoidal Y wave amplitude
@export var breathing_amplitude: float = 3.0
# sinusoidal Y wave frequency
@export var breathing_frequency: float = 1.0
# enable horizontal oscillation
@export var step_enabled: bool = true
# horizontal oscillation speed
@export var step_speed: float = 20.0
# horizontal oscillation distance before reversing
@export var step_distance: float = 30.0

# --- state ---

# flat array of slot contents (null = empty, CDEntity = occupied)
var _slots: Array = []
# current horizontal offset for stepping animation
var _step_offset: float = 0.0
# current phase for breathing animation
var _breathing_phase: float = 0.0
# stepping direction (+1 or -1)
var _step_direction: int = 1
# entities assigned this frame (prevents stale cleanup from removing them)
var _assigned_this_frame: Dictionary = {}

# --- lifecycle ---

# initialize slots array
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	_init_slots()

# --- processing ---

# advance animations, clean stale slots, broadcast move_to targets
func _physics_process(delta: float) -> void:
	# advance breathing phase
	_breathing_phase += delta * breathing_frequency * TAU
	
	# advance stepping offset and reverse at boundary
	if step_enabled:
		_step_offset += step_speed * _step_direction * delta
		if absf(_step_offset) >= step_distance:
			_step_direction *= -1
	
	# auto-assign untracked group members to empty slots
	_auto_assign_slots()
	
	# clean stale slots (invalid or left the group)
	for i in _slots.size():
		var slot_entity: CDEntity = _slots[i]
		if slot_entity == null:
			continue
		if not is_instance_valid(slot_entity):
			_slots[i] = null
			continue
		if _assigned_this_frame.has(slot_entity):
			continue
		if not slot_entity.is_in_group(formation_group):
			_slots[i] = null
	
	# broadcast move_to for all occupied, active slots
	for i in _slots.size():
		var slot_entity: CDEntity = _slots[i]
		if slot_entity == null:
			continue
		if slot_entity.state != CDEnums.EntityState.ACTIVE:
			continue
		var target := _calculate_slot_position(i)
		slot_entity.ensure_signal("move_to")
		slot_entity.emit_signal("move_to", target)
	
	_assigned_this_frame.clear()

# --- slot management ---

# assign an entity to the first empty slot (row-major order)
func _on_slot_requested(entity: CDEntity) -> void:
	if not is_instance_valid(entity):
		return
	
	# skip if already tracked
	if entity in _slots:
		return
	
	# find first empty slot
	var slot_index := -1
	for i in _slots.size():
		if _slots[i] == null:
			slot_index = i
			break
	
	if slot_index == -1:
		push_warning("FormationDirector '%s': no empty slots for '%s'." % [name, entity.name])
		return
	
	# assign and immediately command toward slot
	_slots[slot_index] = entity
	_assigned_this_frame[entity] = true
	
	var target := _calculate_slot_position(slot_index)
	entity.ensure_signal("move_to")
	entity.emit_signal("move_to", target)

# calculate world position for a slot index (grid + step + breathing)
func _calculate_slot_position(slot_index: int) -> Vector2:
	@warning_ignore("integer_division")
	var col := slot_index % columns
	@warning_ignore("integer_division")
	var row := slot_index / columns
	
	# grid layout calculations
	var step_x := cell_size.x + cell_spacing.x
	var step_y := cell_size.y + cell_spacing.y
	var grid_width := columns * step_x - cell_spacing.x
	var grid_height := rows * step_y - cell_spacing.y
	
	# base position centered on director
	var base_x := global_position.x + col * step_x - grid_width * 0.5 + cell_size.x * 0.5
	var base_y := global_position.y + row * step_y - grid_height * 0.5 + cell_size.y * 0.5
	
	# per-row breathing offset
	var breathing := sin(_breathing_phase + row * 0.5) * breathing_amplitude
	
	# horizontal step offset
	var step := _step_offset if step_enabled else 0.0
	
	return Vector2(base_x + step, base_y + breathing)

# auto-detect untracked group members and assign them to empty slots
func _auto_assign_slots() -> void:
	var entities := game.group_registry.get_group(formation_group)
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.state != CDEnums.EntityState.ACTIVE:
			continue
		if entity in _slots:
			continue
		
		# find first empty slot (row-major)
		var slot_index := -1
		for i in _slots.size():
			if _slots[i] == null:
				slot_index = i
				break
		
		if slot_index == -1:
			push_warning("FormationDirector '%s': no empty slots for '%s'." % [name, entity.name])
			continue
		
		_slots[slot_index] = entity
		_assigned_this_frame[entity] = true
		
		var target := _calculate_slot_position(slot_index)
		entity.ensure_signal("move_to")
		entity.emit_signal("move_to", target)

# --- reset ---

# clear all slots and animation state for game restart
func reset() -> void:
	_init_slots()
	_step_offset = 0.0
	_breathing_phase = 0.0
	_step_direction = 1
	_assigned_this_frame.clear()

# initialize the slot array with null entries
func _init_slots() -> void:
	_slots.clear()
	_slots.resize(columns * rows)
	for i in _slots.size():
		_slots[i] = null