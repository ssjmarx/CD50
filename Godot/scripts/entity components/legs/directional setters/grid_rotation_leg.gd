# GridRotationLeg
# Tetris-style rotation with SRS wall-kick offset tables
# Falls back to simple rotation if no TetrominoGuts sibling is found

class_name GridRotationLeg extends CDEntityComponent

# --- exports ---

# SRS wall-kick offset table resource
@export var kick_table: CDWallKick
# rotation increment per step in radians (90° for Tetris)
@export var rotation_step: float = PI / 2.0

# rotation request signals (float spin: +1 CW, -1 CCW)
@export_group("Listen Signals")
@export var rotate_signals: Array[StringName] = [&"rotate"]
# emitted when all kick positions are blocked
@export var rotation_blocked_signals: Array[StringName] = [&"rotation_blocked"]

# --- state ---

# sibling TetrominoGuts for cell offset data (loosely typed to avoid hard dep)
var _tetromino_guts

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# connect rotation listener and find sibling TetrominoGuts
func _on_initialize() -> void:
	for sig in rotate_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_rotate)
	for sig in rotation_blocked_signals:
		entity.ensure_signal(sig)
	
	_tetromino_guts = _find_tetromino_guts()

# --- helpers ---

# find TetrominoGuts sibling by script class name
func _find_tetromino_guts():
	for child in entity.get_children():
		if child.get_script() and child.get_script().get_global_name() == &"TetrominoGuts":
			return child
	return null

# --- signal handlers ---

# attempt rotation with wall kicks, fall back to simple rotation without guts
func _on_rotate(spin: float) -> void:
	if not _tetromino_guts:
		# no guts — fall back to simple rotation
		entity.request_rotation_add(spin * rotation_step)
		return
	
	# calculate current and target rotation indices (0-3)
	var current_index: int = _tetromino_guts.get_rotation_index()
	var target_index: int = (current_index + int(spin)) % 4
	if target_index < 0:
		target_index += 4
	
	# get the target cell offsets and cell size
	var target_offsets: Array = _tetromino_guts.get_offsets_for_rotation(target_index)
	var cell_size := _get_cell_size()
	
	# try base position first (no kick)
	if _validate_cells(target_offsets, Vector2i.ZERO, cell_size):
		_apply_rotation(target_index, Vector2i.ZERO)
		return
	
	# try wall kicks from the kick table
	if kick_table:
		var kicks: Array[Vector2i] = kick_table.get_kicks(current_index, target_index)
		for kick in kicks:
			if _validate_cells(target_offsets, kick, cell_size):
				_apply_rotation(target_index, kick)
				return
	
	# all positions blocked — notify listeners
	for sig in rotation_blocked_signals:
		entity.emit_signal(sig)

# --- validation ---

# check if all cells at given offsets + kick are unoccupied
func _validate_cells(offsets: Array, kick: Vector2i, cell_size: Vector2) -> bool:
	for offset in offsets:
		var world_pos := entity.global_position + Vector2(offset + kick) * cell_size
		if _is_occupied(world_pos):
			return false
	return true

# point-cast to check if a world position is occupied by another body
func _is_occupied(pos: Vector2) -> bool:
	var space_state := entity.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.exclude = [entity.get_rid()]
	var results := space_state.intersect_point(query)
	return results.size() > 0

# --- application ---

# apply the rotation index and optional kick offset to the entity
func _apply_rotation(target_index: int, kick: Vector2i) -> void:
	_tetromino_guts.set_rotation(target_index)
	if kick != Vector2i.ZERO:
		var cell_size := _get_cell_size()
		entity.request_position_add(Vector2(kick) * cell_size)

# read cell_size from sibling GridMovementLeg if present, else default
func _get_cell_size() -> Vector2:
	for child in entity.get_children():
		if child.get_script() and child.get_script().get_global_name() == &"GridMovementLeg":
			return child.cell_size
	return Vector2(16, 16)

# --- cleanup ---

# reset state and disconnect for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in rotate_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_rotate):
			entity.disconnect(sig, _on_rotate)
	_tetromino_guts = null