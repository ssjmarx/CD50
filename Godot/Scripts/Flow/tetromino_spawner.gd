# Tetromino spawner. Manages the lock-spawn cycle for Tetris-style games.
# Handles piece locking (splitting into singles), next piece spawning,
# preview display, bag system, and defeat detection. No grid dependency.

extends UniversalComponent2D

# Bag configuration — any PackedScene can be in the bag
@export var bag: Array[PackedScene] = []
@export var randomizer_mode: String = "bag7"  # "bag7" or "random"

# Settled cell configuration
@export var cell_size: Vector2 = Vector2(18, 18)
@export var settled_cell_scene: PackedScene              # scene for individual settled cells
@export var settled_cell_components: Array[PackedScene] = []
@export var settled_cell_overrides: Array[PropertyOverride] = []
@export var settled_group: String = "settled"

# Active piece configuration
@export var active_piece_components: Array[PackedScene] = []
@export var active_piece_overrides: Array[PropertyOverride] = []

# Preview
@export var preview_origin: Vector2 = Vector2(500, 40)

# Hold piece
@export var enable_hold: bool = false
@export var hold_origin: Vector2 = Vector2(500, 180)

# Starting level — can be overridden via PropertyOverride for arcade modes
@export var starting_level: int = 1

# Level-based gravity speed table. Index 0 = Level 1, index N-1 = Level N.
# Any level beyond the table uses the last value as the floor.
# Modern Guideline: [1.000, 0.793, 0.618, 0.473, 0.355, 0.262, 0.190, 0.135,
#                    0.097, 0.068, 0.047, 0.032, 0.022, 0.015, 0.010]
# NES Tetris:       [0.800, 0.717, 0.633, 0.550, 0.467, 0.383, 0.300, 0.217,
#                    0.133, 0.100, 0.083, 0.083, 0.083, 0.067, 0.050, 0.050,
#                    0.050, 0.033, 0.017]
# Original:         [1.0]
@export var speed_table: Array[float] = [1.000, 0.793, 0.618, 0.473, 0.355,
	0.262, 0.190, 0.135, 0.097, 0.068, 0.047, 0.032, 0.022, 0.015, 0.010]

# Runtime state
var _active_piece: Node = null
var _preview_piece: Node = null
var _held_piece: Node = null          # Frozen piece shown in hold box
var _can_hold: bool = true            # Reset on each fresh spawn
var _held_bag_index: int = -1         # Bag index of the held piece
var _bag_queue: Array[int] = []  # indices into _expanded_bag
var _next_index: int = -1
var _expanded_bag: Array[Dictionary] = []  # { "scene": PackedScene, "overrides": Dictionary }
var _current_level: int = 1
var _current_fall_interval: float

# Emitted when the next piece preview changes
signal next_piece_changed(piece_scene: PackedScene)
# Emitted when the active piece locks (general notification)
signal piece_did_lock
# Emitted when the active piece moves laterally (juice relay)
signal piece_moved
# Emitted when the active piece rotates (juice relay)
signal piece_rotated
# Emitted when the active piece hard drops (juice relay)
signal piece_hard_dropped

# Initialize randomizer, preview, and connect game start
func _ready() -> void:
	game.on_game_start.connect(_on_game_start)
	_current_level = starting_level
	_current_fall_interval = _get_speed_for_level(starting_level)
	_connect_level_monitor()
	if enable_hold:
		game.hold_requested.connect(_on_hold_requested)
	
	if bag.is_empty():
		return
	
	_expand_bag()
	
	if _expanded_bag.is_empty():
		return
	
	if randomizer_mode == "bag7":
		_refill_bag()
	_next_index = _get_next_index()
	# Don't spawn preview here — add_child fails during _ready().
	# _spawn_next() will create the preview on first call.

# Spawn the first piece when the game starts
func _on_game_start() -> void:
	_spawn_next()

# --- Spawn Cycle ---

# Promote the preview piece to active, move to spawn position, and spawn new preview
func _spawn_next() -> void:
	if _expanded_bag.is_empty():
		return
	
	# Check defeat — is spawn position occupied?
	if _is_spawn_blocked():
		game.defeat.emit()
		return
	
	# If no preview exists yet (e.g. first spawn), instantiate one
	if not _preview_piece or not is_instance_valid(_preview_piece):
		var entry = _expanded_bag[_next_index]
		_preview_piece = entry.scene.instantiate()
		_apply_entry_overrides(_preview_piece, entry.overrides)
		game.add_child(_preview_piece)
	
	# Promote preview to active piece
	var piece = _preview_piece
	_preview_piece = null
	_active_piece = piece
	
	# Move to spawn position, reset rotation, and unfreeze
	piece.global_position = global_position
	piece.rotation = 0
	_unfreeze_piece(piece)
	
	# Attach active piece components (brains, hold relay)
	for scene in active_piece_components:
		var comp = scene.instantiate()
		comp.set_meta("_spawner_attached", true)
		piece.add_child(comp)
	
	# Apply property overrides
	for override in active_piece_overrides:
		_apply_override(piece, override)
	
	# Connect to lock detector's piece_locked signal
	var lock_det = _find_lock_detector(piece)
	if lock_det:
		lock_det.piece_locked.connect(_on_piece_locked.bind(piece))
	
	# Connect to movement/rotation/shoot signals for juice relay
	_connect_piece_signals(piece)
	
	# Reset hold eligibility on fresh spawn
	_can_hold = true
	
	# Apply current level's gravity speed to the newly spawned piece
	_apply_gravity_to_piece(piece)
	
	# Pick next piece and spawn preview
	_next_index = _get_next_index()
	_spawn_preview()

# Find the lock detector component on a piece
func _find_lock_detector(piece: Node) -> Node:
	for child in piece.get_children():
		if child.has_signal("piece_locked"):
			return child
		# Also check the piece itself (in case lock_detector is the root)
	return null

# Handle piece lock: split into singles, emit settled, spawn next
func _on_piece_locked(cell_positions: Array[Vector2], piece: Node) -> void:
	piece_did_lock.emit()
	
	# Spawn a settled cell at each position
	for cell_pos in cell_positions:
		_spawn_settled_cell(cell_pos)
	
	# Remove the multi-cell piece
	if is_instance_valid(piece):
		piece.queue_free()
	_active_piece = null
	
	# Notify listeners via game event bus (line_clear_monitor)
	game.piece_settled.emit()
	
	# Brief delay before spawning next piece
	await get_tree().create_timer(0.1).timeout
	if game.current_state == CommonEnums.State.PLAYING:
		_spawn_next()

# Spawn a single settled cell at the given world position
func _spawn_settled_cell(pos: Vector2) -> void:
	if not settled_cell_scene:
		return
	
	var cell = settled_cell_scene.instantiate()
	cell.global_position = pos
	game.add_child(cell)
	cell.add_to_group(settled_group)
	
	# Attach components to the settled cell
	for scene in settled_cell_components:
		var comp = scene.instantiate()
		cell.add_child(comp)
	
	# Apply property overrides
	for override in settled_cell_overrides:
		_apply_override(cell, override)

# --- Preview ---

# Spawn or replace the preview entity at the preview position
func _spawn_preview() -> void:
	# Clean up old preview
	if _preview_piece and is_instance_valid(_preview_piece):
		_preview_piece.queue_free()
	
	if _next_index < 0 or _next_index >= _expanded_bag.size():
		return
	
	var entry = _expanded_bag[_next_index]
	_preview_piece = entry.scene.instantiate()
	_apply_entry_overrides(_preview_piece, entry.overrides)
	_preview_piece.global_position = preview_origin
	_preview_piece.rotation = PI / 2  # Rotate preview 90° clockwise
	game.add_child(_preview_piece)
	
	# Freeze the preview — disable all child processing (brains, legs, components)
	_freeze_piece(_preview_piece)
	
	next_piece_changed.emit(entry.scene)

# --- Hold Piece ---

# Called when the player requests a hold. Swaps active piece with held piece.
func _on_hold_requested() -> void:
	if not enable_hold or not _can_hold:
		return
	if not _active_piece or not is_instance_valid(_active_piece):
		return
	
	# Stop the active piece's lock detector (prevent double-lock)
	var lock_det = _find_lock_detector(_active_piece)
	if lock_det:
		lock_det.set_process(false)
	
	# Disconnect the piece_locked signal to prevent cleanup
	if lock_det and lock_det.is_connected("piece_locked", _on_piece_locked):
		lock_det.piece_locked.disconnect(_on_piece_locked)
	
	_can_hold = false
	
	# Strip active components (player_control, hold_relay) to prevent duplicates on swap
	_strip_active_components(_active_piece)
	
	# Freeze the active piece (disable all child processing)
	_freeze_piece(_active_piece)
	
	if _held_piece and is_instance_valid(_held_piece):
		# Swap: put held piece into active, active into held
		var old_held = _held_piece
		var old_held_index = _held_bag_index
		
		# Store current active as held
		_held_piece = _active_piece
		_held_bag_index = _get_current_bag_index(_active_piece)
		_position_hold_piece()
		
		# Use old held as next piece
		_active_piece = null
		_swap_in_held_piece(old_held, old_held_index)
	else:
		# No held piece yet: hold active, spawn new from queue
		_held_piece = _active_piece
		_held_bag_index = _get_current_bag_index(_active_piece)
		_position_hold_piece()
		_active_piece = null
		
		# Spawn next from queue
		_next_index = _get_next_index()
		_spawn_preview()
		await get_tree().create_timer(0.05).timeout
		if game.current_state == CommonEnums.State.PLAYING:
			_spawn_next()

# Position the held piece at the hold display origin
func _position_hold_piece() -> void:
	if _held_piece and is_instance_valid(_held_piece):
		_held_piece.global_position = hold_origin
		_held_piece.rotation = PI / 2  # Rotate hold piece 90° clockwise
		# Clear ghost offsets so the ghost doesn't project from hold position back onto the field
		if "ghost_offsets" in _held_piece:
			_held_piece.ghost_offsets.clear()
			_held_piece.queue_redraw()

# Take a held/frozen piece and make it the active piece
func _swap_in_held_piece(piece: Node, _bag_index: int) -> void:
	if not is_instance_valid(piece):
		return
	
	# Check defeat — is spawn position occupied?
	if _is_spawn_blocked():
		game.defeat.emit()
		return
	
	_active_piece = piece
	piece.global_position = global_position
	piece.rotation = 0
	_unfreeze_piece(piece)
	
	# Re-attach active piece components
	for scene in active_piece_components:
		var comp = scene.instantiate()
		comp.set_meta("_spawner_attached", true)
		piece.add_child(comp)
	
	# Apply property overrides
	for override in active_piece_overrides:
		_apply_override(piece, override)
	
	# Connect to lock detector
	var lock_det = _find_lock_detector(piece)
	if lock_det:
		lock_det.piece_locked.connect(_on_piece_locked.bind(piece))
	
	# Connect to movement/rotation/hard_drop signals for juice relay
	_connect_piece_signals(piece)
	
	_apply_gravity_to_piece(piece)

# Determine which bag index a piece corresponds to (by matching shape/color)
func _get_current_bag_index(piece: Node) -> int:
	if not is_instance_valid(piece):
		return 0
	for i in range(_expanded_bag.size()):
		var entry = _expanded_bag[i]
		if entry.scene.resource_path == piece.get_scene_file_path():
			return i
		# Match by shape property if available
		if "shape" in piece and entry.overrides.has("shape"):
			if piece.shape == entry.overrides["shape"]:
				return i
	return 0

# --- Preview Freeze ---

# Disable all processing on child nodes (brains, legs, gravity, rotation, etc.)
# Collision shapes remain intact for rendering — the piece just doesn't move.
func _freeze_piece(piece: Node) -> void:
	if not is_instance_valid(piece):
		return
	for child in piece.get_children():
		child.set_process(false)
		child.set_physics_process(false)
		child.set_process_unhandled_input(false)

# Re-enable all processing on child nodes (used when preview becomes active)
func _unfreeze_piece(piece: Node) -> void:
	if not is_instance_valid(piece):
		return
	for child in piece.get_children():
		child.set_process(true)
		child.set_physics_process(true)
		child.set_process_unhandled_input(true)

# Remove spawner-attached components from a piece (used before holding).
# This prevents duplicate components when the piece is swapped back later.
func _strip_active_components(piece: Node) -> void:
	if not is_instance_valid(piece):
		return
	var to_remove: Array[Node] = []
	for child in piece.get_children():
		if child.has_meta("_spawner_attached"):
			to_remove.append(child)
	for child in to_remove:
		piece.remove_child(child)
		child.queue_free()

# --- Defeat Detection ---

# Check if the spawn position is occupied by a settled cell
func _is_spawn_blocked() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results = space_state.intersect_point(query)
	for result in results:
		var body = result["collider"]
		if body and body.is_in_group(settled_group):
			return true
	return false

# --- Bag Expansion ---

# Expand the user's bag into _expanded_bag. For scenes with a Shape enum,
# creates one entry per enum value with property overrides. For scenes without,
# adds a single entry with no overrides.
func _expand_bag() -> void:
	_expanded_bag.clear()
	
	for scene in bag:
		var temp: Node = scene.instantiate()
		var has_shape_enum: bool = false
		
		# Check if the script has a Shape enum constant
		var script = temp.get_script()
		var constants = script.get_script_constant_map() if script else {}
		if constants.has("Shape") and constants["Shape"] is Dictionary:
			var shape_enum = constants["Shape"]
			has_shape_enum = true
			for shape_name in shape_enum:
				_expanded_bag.append({
					"scene": scene,
					"overrides": { "shape": shape_enum[shape_name] }
				})
		
		if not has_shape_enum:
			_expanded_bag.append({
				"scene": scene,
				"overrides": {}
			})
		
		temp.queue_free()

# Apply property overrides from an expanded bag entry to a node.
# Must be called BEFORE add_child() so _ready() sees the correct values.
func _apply_entry_overrides(node: Node, overrides: Dictionary) -> void:
	for prop_name in overrides:
		node.set(prop_name, overrides[prop_name])

# --- Randomizer ---

# Refill the bag queue with all indices, shuffled
func _refill_bag() -> void:
	_bag_queue.assign(range(_expanded_bag.size()))
	_bag_queue.shuffle()

# Return the next bag index using the configured randomizer mode
func _get_next_index() -> int:
	match randomizer_mode:
		"bag7":
			if _bag_queue.is_empty():
				_refill_bag()
			return _bag_queue.pop_back()
		_:
			return randi() % _expanded_bag.size()

# --- Level-Based Gravity ---

# Find and connect to the LineClearMonitor's level_changed signal
func _connect_level_monitor() -> void:
	if not game:
		return
	for child in game.get_children():
		if child.has_signal("level_changed"):
			child.level_changed.connect(_on_level_changed)
			return

# Recalculate fall speed when level changes, and update active piece immediately
func _on_level_changed(new_level: int) -> void:
	_current_level = new_level
	_current_fall_interval = _get_speed_for_level(new_level)
	
	if _active_piece and is_instance_valid(_active_piece):
		_apply_gravity_to_piece(_active_piece)

# Look up fall interval from speed_table. Levels beyond the table use the last entry.
func _get_speed_for_level(level: int) -> float:
	if speed_table.is_empty():
		return 1.0
	var idx = mini(level - 1, speed_table.size() - 1)
	return speed_table[maxi(0, idx)]

# Find the grid_gravity child on a piece and set its fall_interval
func _apply_gravity_to_piece(piece: Node) -> void:
	for child in piece.get_children():
		if "fall_interval" in child:
			child.fall_interval = _current_fall_interval
			return

# --- Piece Signal Relay ---

# Connect to movement/rotation/hard_drop signals on the active piece for juice relay
func _connect_piece_signals(piece: Node) -> void:
	for child in piece.get_children():
		if child.has_signal("moved"):
			child.moved.connect(func(): piece_moved.emit())
		if child.has_signal("rotated"):
			child.rotated.connect(func(): piece_rotated.emit())
		if child.has_signal("hard_dropped"):
			child.hard_dropped.connect(func(): piece_hard_dropped.emit())

# --- Utility ---

# Apply a PropertyOverride to a target node
func _apply_override(root: Node, override: PropertyOverride) -> void:
	var target = root.get_node_or_null(override.node_path)
	if target:
		target.set(override.property_name, override.value)
