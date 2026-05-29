# GridMovementLeg
# Moves entity by a fixed grid step if target cell is unoccupied
# Emits step_blocked when collision prevents movement (for lock detection)

class_name GridMovementLeg extends CDEntityComponent

# --- exports ---

# size of each grid cell in pixels
@export var cell_size: Vector2 = Vector2(16, 16)
# whether to check for occupied cells before moving
@export var check_collision: bool = true

# emitted when a step is blocked by collision (Vector2 direction)
@export_group("Emit Signals")
@export var step_blocked_signals: Array[StringName] = [&"step_blocked"]

# directional input signals (Vector2 direction, snapped to axis)
@export_group("Listen Signals")
@export var move_signals: Array[StringName] = [&"move"]

# --- lifecycle ---

# set component category
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STEERING
	super._ready()

# ensure emit signals and connect move listener
func _on_initialize() -> void:
	for sig in step_blocked_signals:
		entity.ensure_signal(sig)
	for sig in move_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_move)

# --- signal handlers ---

# attempt to move one cell in the given direction, emit blocked if occupied
func _on_move(direction: Vector2) -> void:
	var step := direction * cell_size
	var target_pos := entity.global_position + step
	
	# check if target cell is blocked
	if check_collision and _is_occupied(target_pos):
		for sig in step_blocked_signals:
			entity.emit_signal(sig, direction)
		return
	
	entity.request_position_add(step)

# --- helpers ---

# point-cast to check if a world position is occupied by another body
func _is_occupied(pos: Vector2) -> bool:
	var space_state := entity.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.exclude = [entity.get_rid()]
	var results := space_state.intersect_point(query)
	return results.size() > 0

# --- cleanup ---

# disconnect move listener for pool reuse
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in move_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_move):
			entity.disconnect(sig, _on_move)