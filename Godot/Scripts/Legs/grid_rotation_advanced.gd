# Advanced grid rotation leg. Rotates multi-cell body offsets with wall kick
# support. Uses physics queries for validation — no external grid dependency.

extends UniversalComponent

# Which body signal triggers rotation (default: thrust for Block Drop rotate)
@export var rotation_signal: String = "thrust"

# Rotation direction
@export var clockwise: bool = true

# Must match grid_movement.step_size and body tile_size
@export var step_size: float = 18.0

# Ordered kick attempts (in grid cells, converted to pixels via step_size)
@export var kick_offsets: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-2, 0),
	Vector2i(2, 0),
]

# Emitted after a successful rotation
signal rotated

# Connect to the configured rotation signal on parent
func _ready() -> void:
	if parent.has_signal(rotation_signal):
		parent.connect(rotation_signal, _on_rotate)

# Handle rotation signal — attempt rotation with wall kick fallbacks
func _on_rotate(_event: InputEvent = null) -> void:
	#print("on rotate")
	_try_rotate()

# Attempt rotation with wall kick fallbacks; emit rotated on success
func _try_rotate() -> bool:
	#print("trying rotation")
	if not parent.has_method("update_offsets"):
		#print("parent doesnt have update offsets")
		return false
	
	var old_offsets: Array[Vector2i] = parent.current_offsets.duplicate()
	var rotated_offsets = _get_rotated_offsets(old_offsets)   # renamed
	#print("offsets calculated")
	
	# Try each kick offset
	for kick in kick_offsets:
		#print("checking kick offset")
		var kick_displacement = Vector2(kick.x * step_size, kick.y * step_size)
		if _can_place_with_kick(rotated_offsets, kick_displacement):   # renamed
			#print("kicking")
			if kick != Vector2i.ZERO:
				parent.position += kick_displacement
			parent.update_offsets(rotated_offsets)   # renamed
			rotated.emit()   # now correctly refers to the signal
			return true
	
	return false

# Rotate all offsets 90 degrees
func _get_rotated_offsets(offsets: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in offsets:
		if clockwise:
			result.append(Vector2i(-offset.y, offset.x))
		else:
			result.append(Vector2i(offset.y, -offset.x))
	return result

# Check if all rotated cells can be placed at parent position + kick displacement
func _can_place_with_kick(offsets: Array[Vector2i], kick_displacement: Vector2) -> bool:
	#print("checking kick")
	var space_state = parent.get_world_2d().direct_space_state
	var parent_pos = parent.global_position + kick_displacement
	
	for offset in offsets:
		var cell_pos = parent_pos + Vector2(offset.x * step_size, offset.y * step_size)
		
		# Check bounds
		if cell_pos.x < parent.x_min or cell_pos.x > parent.x_max:
			return false
		if cell_pos.y < parent.y_min or cell_pos.y > parent.y_max:
			return false
		
		# Check physics occupancy
		var query = PhysicsPointQueryParameters2D.new()
		query.position = cell_pos
		query.collision_mask = parent.collision_mask
		query.exclude = [parent.get_rid()]
		
		var results = space_state.intersect_point(query)
		if results.size() > 0:
			return false
	
	return true
