# Swarm controller player. Player-driven variant of swarm_controller.
# Reads left/right/shoot input to drive invader swarm movement and broadside firing.
# Manages wave progression: when invaders reach the bottom, awards points,
# destroys all entities, and spawns the next wave with scaling paddle cannon count.

extends UniversalComponent2D

# Swarm configuration
@export var invader_scene: PackedScene
@export var invader_group: String = "invaders"
@export var bus_group: String = "swarm_bus"
@export var swarm_step_size: float = 18.0

# Boundaries
@export var boundary_left: float = 32.0
@export var boundary_right: float = 608.0
@export var boundary_bottom: float = 340.0
@export var step_down_distance: int = 6

# Grid configuration for invader formation
@export var grid_columns: int = 14
@export var grid_rows: int = 4
@export var grid_width: int = 16
@export var grid_height: int = 16
@export var grid_spacing: int = 8
@export var grid_start_position: Vector2 = Vector2(320, 56)

# Scoring
@export var wave_score: int = 100

# Wave management
@export var wave_delay: float = 2.0
@export var victory_on_wave_complete: bool = false

# Checkerboard indicators (left and right boundary markers)
@export var checkerboard_left: NodePath
@export var checkerboard_right: NodePath

# Column detection tolerance
@export var column_tolerance: float = 16.0

# DAS (Delayed Auto Shift) — auto-repeats held direction through boundary checks
@export var das_delay: float = 0.2
@export var das_repeat: float = 0.05

# Emitted each time the swarm steps
signal swarm_move(direction: Vector2)

# Runtime state
var _direction: Vector2 = Vector2.RIGHT
var _wave_count: int = 0
var _transitioning: bool = false
var _survivor_count: int = 0

# DAS runtime state
var _das_held_direction: Vector2 = Vector2.ZERO
var _das_timer: float = 0.0
var _das_active: bool = false

func _ready() -> void:
	add_to_group(bus_group)
	GroupCache.mark_dirty(bus_group)
	await get_tree().process_frame
	_update_checkerboards()
	game.on_game_start.connect(_on_game_start)

# Initial wave spawn when the game starts
func _on_game_start() -> void:
	_survivor_count = grid_columns * grid_rows
	_spawn_invader_formation()

func _physics_process(delta: float) -> void:
	if _transitioning:
		return
	if game.current_state != CommonEnums.State.PLAYING:
		return
	
	# Determine held direction from input
	var held_dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("button_left"):
		held_dir = Vector2.LEFT
	elif Input.is_action_pressed("button_right"):
		held_dir = Vector2.RIGHT
	
	# Detect new press (direction changed or started)
	if held_dir != _das_held_direction:
		if held_dir != Vector2.ZERO:
			# New direction pressed: immediate step + start DAS
			_do_step(held_dir)
			_das_held_direction = held_dir
			_das_timer = 0.0
			_das_active = false
		else:
			# Released: reset DAS
			_das_held_direction = Vector2.ZERO
			_das_timer = 0.0
			_das_active = false
	elif _das_held_direction != Vector2.ZERO:
		# Same direction held: tick DAS timer
		_das_timer += delta
		if _das_active:
			if _das_timer >= das_repeat:
				_das_timer = 0.0
				_do_step(_das_held_direction)
		elif _das_timer >= das_delay:
			_das_active = true
			_das_timer = 0.0
			_do_step(_das_held_direction)
	
	# Broadside fire
	if Input.is_action_just_pressed("button_r"):
		_do_broadside()

# Execute one step in the pressed direction. If the swarm would pass a boundary
# on the target side, step down and reverse instead. Non-target boundary blocks movement.
func _do_step(dir: Vector2) -> void:
	if get_group_count(invader_group) == 0:
		return
	
	# Check if moving in this direction would breach a boundary
	if _would_pass_boundary(dir):
		# Only step down if this is the target direction (shown by checkerboard)
		if dir == _direction:
			for i in range(step_down_distance):
				swarm_move.emit(Vector2.DOWN)
			
			_direction = -_direction
			_update_checkerboards()
			
			# Check bottom after stepping down
			if _is_at_bottom():
				_on_wave_complete()
		# Otherwise (non-target boundary): blocked, no movement
		return
	
	# Normal horizontal step
	swarm_move.emit(dir)

# Fire all bottom-row invaders (broadside: aim down then shoot)
func _do_broadside() -> void:
	var members := get_group_nodes(invader_group)
	for member in members:
		if not is_instance_valid(member):
			continue
		if _is_on_bottom_edge(member, members):
			member.aim.emit(Vector2.DOWN)
			member.shoot.emit()

# Check if a member is the bottommost in its column
func _is_on_bottom_edge(member: Node, members: Array) -> bool:
	var my_pos: Vector2 = member.global_position
	for other in members:
		if other == member:
			continue
		if not is_instance_valid(other):
			continue
		if abs(other.global_position.x - my_pos.x) <= column_tolerance:
			if other.global_position.y > my_pos.y:
				return false
	return true

# Check if moving in the given direction would push any invader past a boundary
func _would_pass_boundary(dir: Vector2) -> bool:
	for member in get_group_nodes(invader_group):
		if not is_instance_valid(member):
			continue
		var next_x: float = member.global_position.x + dir.x * swarm_step_size
		if dir.x > 0 and next_x >= boundary_right:
			return true
		if dir.x < 0 and next_x <= boundary_left:
			return true
	return false

# Check if any invader has reached the bottom boundary
func _is_at_bottom() -> bool:
	for member in get_group_nodes(invader_group):
		if not is_instance_valid(member):
			continue
		if member.global_position.y >= boundary_bottom:
			return true
	return false

# Handle successful wave: award points, destroy entities, respawn
func _on_wave_complete() -> void:
	_transitioning = true
	game.add_score(wave_score)
	
	# Disable GroupMonitor during wave transition to prevent false defeat
	var group_monitor = game.find_child("GroupMonitor", false, false)
	if group_monitor:
		group_monitor.set_physics_process(false)
	
	# Remember how many invaders survived before destroying them
	_survivor_count = get_group_count(invader_group)
	
	# Victory instead of respawning (arcade mode: single wave wins)
	if victory_on_wave_complete:
		game.victory.emit()
		_transitioning = false
		return
	
	# Destroy all invaders (cannons persist across waves)
	_destroy_group(invader_group)
	
	# Wait, then spawn next wave
	await get_tree().create_timer(wave_delay).timeout
	
	if game.current_state == CommonEnums.State.GAME_OVER:
		return
	
	_wave_count += 1
	_direction = Vector2.RIGHT
	_update_checkerboards()
	
	_spawn_invader_formation()
	
	# Wait one frame for entities to settle, then re-enable GroupMonitor
	await get_tree().process_frame
	if group_monitor:
		group_monitor._previous_count = -1
		group_monitor.set_physics_process(true)
	_transitioning = false

# Spawn the invader grid formation
func _spawn_invader_formation() -> void:
	if invader_scene == null:
		return
	
	var step_x = grid_width + grid_spacing
	var step_y = grid_height + grid_spacing
	var total_w = grid_columns * step_x - grid_spacing
	var total_h = grid_rows * step_y - grid_spacing
	var origin_x = grid_start_position.x - total_w / 2.0
	var origin_y = grid_start_position.y - total_h / 2.0
	
	var spawned: int = 0
	for row in grid_rows:
		for col in grid_columns:
			if spawned >= _survivor_count:
				return
			var invader = invader_scene.instantiate()
			invader.position = Vector2(
				origin_x + col * step_x + grid_width / 2.0,
				origin_y + row * step_y + grid_height / 2.0
			)
			game.add_child(invader)
			spawned += 1

# Destroy all members of a group
func _destroy_group(group_name: String) -> void:
	var members := get_group_nodes(group_name)
	for member in members:
		if is_instance_valid(member):
			member.queue_free()

# Show/hide checkerboard indicators based on current direction
func _update_checkerboards() -> void:
	if checkerboard_left:
		var cb_left = get_node_or_null(checkerboard_left)
		if cb_left:
			cb_left.visible = (_direction.x < 0)
	if checkerboard_right:
		var cb_right = get_node_or_null(checkerboard_right)
		if cb_right:
			cb_right.visible = (_direction.x > 0)