## GridRotationLeg
## Produces: a discrete rotation step using SRS wall-kick offset tables.
## Consumes: entity.blackboard["rotation_spin"] (edge-detected).

class_name GridRotationLeg extends CDEntityComponent

## --- exports ---

## SRS wall-kick offset table resource
@export var kick_table: CDWallKick
## rotation increment per step in radians (90° for Tetris)
@export var rotation_step: float = PI / 2.0

@export_group("Blackboard Keys")
## key to read rotation spin from (float: +1 CW, -1 CCW)
@export var spin_key: StringName = &"rotation_spin"

@export_group("Emit Signals")
## emitted when all kick positions are blocked (zero-arg)
@export var rotation_blocked_signals: Array[StringName] = [&"rotation_blocked"]

## --- state ---

## previous frame's spin for edge detection
var _prev_spin: float = 0.0
## sibling TetrominoGuts for cell offset data (loosely typed to avoid hard dep)
var _tetromino_guts

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

## on initialize
func _on_initialize() -> void:
	for sig in rotation_blocked_signals:
		entity.ensure_signal(sig)
	_tetromino_guts = _find_tetromino_guts()

## physics process
func _physics_process(_delta: float) -> void:
	if not entity:
		return
	
	var spin: float = entity.blackboard.get(spin_key, 0.0)
	
	if spin != 0.0 and spin != _prev_spin:
		_on_rotate(spin)
	
	_prev_spin = spin

## find TetrominoGuts sibling by script class name
func _find_tetromino_guts():
	for child in entity.get_children():
		if child.get_script() and child.get_script().get_global_name() == &"TetrominoGuts":
			return child
	return null

## attempt rotation with wall kicks, fall back to simple rotation without guts
func _on_rotate(spin: float) -> void:
	if not _tetromino_guts:
		entity.request_rotation_add(spin * rotation_step)
		return

	## calculate current and target rotation indices (0-3)
	var current_index: int = _tetromino_guts.get_rotation_index()
	var target_index: int = (current_index + int(spin)) % 4
	if target_index < 0:
		target_index += 4

	var target_offsets: Array = _tetromino_guts.get_offsets_for_rotation(target_index)
	var cell_size := _get_cell_size()

	if _validate_cells(target_offsets, Vector2i.ZERO, cell_size):
		_apply_rotation(target_index, Vector2i.ZERO)
		return

	## try wall kicks from the kick table
	if kick_table:
		var kicks: Array[Vector2i] = kick_table.get_kicks(current_index, target_index)
		for kick in kicks:
			if _validate_cells(target_offsets, kick, cell_size):
				_apply_rotation(target_index, kick)
				return

	for sig in rotation_blocked_signals:
		entity.bus_emit(sig)

## check if all cells at given offsets + kick are unoccupied
func _validate_cells(offsets: Array, kick: Vector2i, cell_size: Vector2) -> bool:
	for offset in offsets:
		var world_pos := entity.global_position + Vector2(offset + kick) * cell_size
		if _is_occupied(world_pos):
			return false
	return true

## point-cast to check if a world position is occupied by another body
func _is_occupied(pos: Vector2) -> bool:
	var space_state := entity.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.exclude = [entity.get_rid()]
	var results := space_state.intersect_point(query)
	return results.size() > 0

## apply the rotation index and optional kick offset to the entity
func _apply_rotation(target_index: int, kick: Vector2i) -> void:
	_tetromino_guts.set_rotation(target_index)
	if kick != Vector2i.ZERO:
		var cell_size := _get_cell_size()
		entity.request_position_add(Vector2(kick) * cell_size)

## read cell_size from sibling GridMovementLeg if present, else default
func _get_cell_size() -> Vector2:
	for child in entity.get_children():
		if child.get_script() and child.get_script().get_global_name() == &"GridMovementLeg":
			return child.cell_size
	return Vector2(16, 16)

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_prev_spin = 0.0
	_tetromino_guts = null