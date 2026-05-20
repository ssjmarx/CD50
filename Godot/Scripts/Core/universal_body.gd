# Universal base class for blackboard architecture. Routes signals between components, provides position clamping and axis locking.

class_name UniversalBody extends CharacterBody2D

# Signals from Brains (Components listen after processing)
@warning_ignore("unused_signal")
signal move(direction: Vector2)
@warning_ignore("unused_signal")
signal move_to(position: Vector2)
@warning_ignore("unused_signal")
signal aim(direction: Vector2)
@warning_ignore("unused_signal")
signal aim_at(position: Vector2)
@warning_ignore("unused_signal")
signal body_collided(collider: Node, normal: Vector2)

# Named buttons (semantic)
@warning_ignore("unused_signal")
signal shoot
@warning_ignore("unused_signal")
signal end_shoot
@warning_ignore("unused_signal")
signal thrust
@warning_ignore("unused_signal")
signal end_thrust

# Generic buttons (by Input Map name)
@warning_ignore("unused_signal")
signal button_1
@warning_ignore("unused_signal")
signal end_button_1
@warning_ignore("unused_signal")
signal button_2
@warning_ignore("unused_signal")
signal end_button_2
@warning_ignore("unused_signal")
signal button_3
@warning_ignore("unused_signal")
signal end_button_3
@warning_ignore("unused_signal")
signal button_4
@warning_ignore("unused_signal")
signal end_button_4
@warning_ignore("unused_signal")
signal button_5
@warning_ignore("unused_signal")
signal end_button_5
@warning_ignore("unused_signal")
signal button_6
@warning_ignore("unused_signal")
signal end_button_6

# Number keys
@warning_ignore("unused_signal")
signal number_1
@warning_ignore("unused_signal")
signal end_number_1
@warning_ignore("unused_signal")
signal number_2
@warning_ignore("unused_signal")
signal end_number_2
@warning_ignore("unused_signal")
signal number_3
@warning_ignore("unused_signal")
signal end_number_3
@warning_ignore("unused_signal")
signal number_4
@warning_ignore("unused_signal")
signal end_number_4
@warning_ignore("unused_signal")
signal number_5
@warning_ignore("unused_signal")
signal end_number_5
@warning_ignore("unused_signal")
signal number_6
@warning_ignore("unused_signal")
signal end_number_6
@warning_ignore("unused_signal")
signal number_7
@warning_ignore("unused_signal")
signal end_number_7
@warning_ignore("unused_signal")
signal number_8
@warning_ignore("unused_signal")
signal end_number_8
@warning_ignore("unused_signal")
signal number_9
@warning_ignore("unused_signal")
signal end_number_9
@warning_ignore("unused_signal")
signal number_0
@warning_ignore("unused_signal")
signal end_number_0


# Entity dimensions for collision and clamping
@export var width: int = 4
@export var height: int = 4

# Position constraints (clamping bounds). -1 = auto-detect from game playfield_size.
@export var x_min: float = -1.0
@export var x_max: float = -1.0
@export var y_min: float = -1.0
@export var y_max: float = -1.0

# Extra margin added to auto-detected playfield bounds. Used by screen-wrapping entities and bullets.
@export var bounds_margin: int = 0

# Movement axis locks (enforced at end of physics frame, overrides all brains/legs)
var _axis_lock_x_pos: float
var _axis_lock_y_pos: float

@export var lock_x: bool = false:
	set(value):
		if value and not lock_x: _axis_lock_x_pos = position.x
		lock_x = value

@export var lock_y: bool = false:
	set(value):
		if value and not lock_y: _axis_lock_y_pos = position.y
		lock_y = value

# Collision groups for CollisionMatrix configuration (first is primary layer)
@export var collision_groups: Array[String] = []

func _enter_tree() -> void:
	for group in get_groups():
		GroupCache.mark_dirty(group)

func _exit_tree() -> void:
	for group in get_groups():
		GroupCache.mark_dirty(group)

func _ready() -> void:
	# Run after all Legs and friction components
	process_priority = 100
	process_physics_priority = 100
	
	# Resolve sentinel bounds from game playfield_size or viewport
	var pf := _get_playfield()
	if x_min < 0.0: x_min = 0.0 - bounds_margin
	if x_max < 0.0: x_max = pf.x + bounds_margin
	if y_min < 0.0: y_min = 0.0 - bounds_margin
	if y_max < 0.0: y_max = pf.y + bounds_margin
	
	# Capture initial position for axis locks
	_axis_lock_x_pos = position.x
	_axis_lock_y_pos = position.y
	
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width, height)

	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.shape = shape

# Get playfield dimensions from game or viewport fallback
func _get_playfield() -> Vector2:
	var game := UniversalGameScript.find_ancestor(self)
	if game and "playfield_size" in game:
		return game.playfield_size
	return get_viewport().get_visible_rect().size

func _physics_process(delta: float) -> void:
	# Apply shared velocity to position (priority 100, runs after Legs)
	move_parent_physics(velocity * delta)
	
	# Clamp position to movement bounds (use global_position for nested bodies)
	global_position = global_position.clamp(Vector2(x_min, y_min), Vector2(x_max, y_max))
	
	# Zero velocity when hitting bounds (prevents accumulating acceleration against walls)
	if global_position.x <= x_min or global_position.x >= x_max:
		velocity.x = 0
	if global_position.y <= y_min or global_position.y >= y_max:
		velocity.y = 0
	
	# Enforce axis locks — final override, cannot be broken by any brain or leg
	if lock_x:
		position.x = _axis_lock_x_pos
		velocity.x = 0
	if lock_y:
		position.y = _axis_lock_y_pos
		velocity.y = 0

# Move entity by displacement, clamp within bounds (instant, no physics)
func move_parent(movement: Vector2) -> void:
	var new_pos = global_position + movement
	new_pos.x = clampf(new_pos.x, x_min + width / 2.0, x_max - width / 2.0)
	new_pos.y = clampf(new_pos.y, y_min + height / 2.0, y_max - height / 2.0)
	global_position = new_pos

# Move entity toward target, clamp target within bounds (instant, no physics)
func move_parent_toward(target: Vector2, max_distance: float) -> void:
	var clamped_target = target.clamp(Vector2(x_min + width / 2.0, y_min + height / 2.0), Vector2(x_max - width / 2.0, y_max - height / 2.0))
	global_position = global_position.move_toward(clamped_target, max_distance)

# Move entity by displacement with physics collision detection and signalling
func move_parent_physics(movement: Vector2) -> KinematicCollision2D:
	var collision = move_and_collide(movement)
	if collision:
		body_collided.emit(collision.get_collider(), collision.get_normal())
		# Nudge away from surface to prevent re-collision
		position += collision.get_normal() * 0.5
		# Re-apply remainder in bounced direction (BounceOnHit already flipped velocity)
		var remainder = collision.get_remainder().bounce(collision.get_normal())
		if remainder.length() > 0.01:
			move_and_collide(remainder)
	return collision


# Move entity toward target with physics collision detection
func move_parent_physics_toward(target: Vector2, max_distance: float) -> KinematicCollision2D:
	var direction: Vector2 = (target - position).normalized()
	var distance: float = minf(position.distance_to(target), max_distance)
	return move_and_collide(direction * distance)
