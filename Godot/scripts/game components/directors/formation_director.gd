## manages a grid of named slots for formation entities.
class_name FormationDirector extends CDGameComponent

@export var formation_group: StringName = &"formation"
@export var slot_request_signal: StringName = &"request_formation_slot"
@export var columns: int = 10
@export var rows: int = 5
@export var cell_size: Vector2 = Vector2(16, 16)
@export var cell_spacing: Vector2 = Vector2(4, 4)
@export var breathing_amplitude: float = 3.0
@export var breathing_frequency: float = 1.0
@export var step_enabled: bool = true
@export var step_speed: float = 20.0
@export var step_distance: float = 30.0

var _slots: Array = []
var _step_offset: float = 0.0
var _breathing_phase: float = 0.0
var _step_direction: int = 1
var _assigned_this_frame: Dictionary = {}

func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES
	_init_slots()

func _on_initialize() -> void:
	if slot_request_signal != &"":
		game.bus_connect(slot_request_signal, _on_slot_requested)

## per-frame: update animations, clean stale slots, broadcast move_to
func _physics_process(delta: float) -> void:
	_breathing_phase += delta * breathing_frequency * TAU
	if step_enabled:
		_step_offset += step_speed * _step_direction * delta
		if absf(_step_offset) >= step_distance:
			_step_direction *= -1

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

## synchronous game bus handler — assigns first empty slot (row-major order)
func _on_slot_requested(entity: CDEntity) -> void:
	if not is_instance_valid(entity):
		return

	if entity in _slots:
		return

	var slot_index := -1
	for i in _slots.size():
		if _slots[i] == null:
			slot_index = i
			break

	if slot_index == -1:
		push_warning("FormationDirector '%s': no empty slots for '%s'." % [name, entity.name])
		return

	_slots[slot_index] = entity
	_assigned_this_frame[entity] = true

	var target := _calculate_slot_position(slot_index)
	entity.ensure_signal("move_to")
	entity.emit_signal("move_to", target)

## calculates world position for a slot index
func _calculate_slot_position(slot_index: int) -> Vector2:
	@warning_ignore("integer_division")
	var col := slot_index % columns
	@warning_ignore("integer_division")
	var row := slot_index / columns

	var step_x := cell_size.x + cell_spacing.x
	var step_y := cell_size.y + cell_spacing.y
	var grid_width := columns * step_x - cell_spacing.x
	var grid_height := rows * step_y - cell_spacing.y

	var base_x := global_position.x + col * step_x - grid_width * 0.5 + cell_size.x * 0.5
	var base_y := global_position.y + row * step_y - grid_height * 0.5 + cell_size.y * 0.5

	var breathing := sin(_breathing_phase + row * 0.5) * breathing_amplitude

	var step := _step_offset if step_enabled else 0.0

	return Vector2(base_x + step, base_y + breathing)

func reset() -> void:
	_init_slots()
	_step_offset = 0.0
	_breathing_phase = 0.0
	_step_direction = 1
	_assigned_this_frame.clear()

func _init_slots() -> void:
	_slots.clear()
	_slots.resize(columns * rows)
	for i in _slots.size():
		_slots[i] = null
