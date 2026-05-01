# Universal base class for blackboard architecture. Routes signals between components, provides position clamping and axis locking.
class_name UniversalBody extends CharacterBody2D

# Signals from Brains (Components listen after processing)
@warning_ignore("unused_signal")
signal move(direction: Vector2)
@warning_ignore("unused_signal")
signal move_to(position: Vector2)
@warning_ignore("unused_signal")
signal action(button: InputEvent)
@warning_ignore("unused_signal")
signal end_action(button: InputEvent)
@warning_ignore("unused_signal")
signal shoot(button: InputEvent)
@warning_ignore("unused_signal")
signal end_shoot(button: InputEvent)
@warning_ignore("unused_signal")
signal thrust(button: InputEvent)
@warning_ignore("unused_signal")
signal end_thrust(button: InputEvent)
@warning_ignore("unused_signal")
signal aim(direction: Vector2)
@warning_ignore("unused_signal")
signal aim_at(position: Vector2)
@warning_ignore("unused_signal")
signal body_collided(collider: Node, normal: Vector2)


# Entity dimensions for collision and clamping
@export var width: int = 4
@export var height: int = 4

# Position constraints (clamping bounds)
@export var x_min: float = 0.0
@export var x_max: float = 640.0
@export var y_min: float = 0.0
@export var y_max: float = 360.0

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

func _ready() -> void:
	# Run after all Legs and friction components
	process_priority = 100
	process_physics_priority = 100
	
	# Capture initial position for axis locks
	_axis_lock_x_pos = position.x
	_axis_lock_y_pos = position.y
	
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width, height)

	if $CollisionShape2D:
		$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	# Apply shared velocity to position (priority 100, runs after Legs)
	move_parent_physics(velocity * delta)
	
	# Enforce axis locks — final override, cannot be broken by any brain or leg
	if lock_x:
		position.x = _axis_lock_x_pos
		velocity.x = 0
	if lock_y:
		position.y = _axis_lock_y_pos
		velocity.y = 0

# Move entity by displacement, clamp within bounds (instant, no physics)
func move_parent(movement: Vector2) -> void:
	position.x = clampf(position.x + movement.x, x_min + width / 2.0, x_max - width / 2.0)
	position.y = clampf(position.y + movement.y, y_min + height / 2.0, y_max - height / 2.0)

# Move entity toward target, clamp target within bounds (instant, no physics)
func move_parent_toward(target: Vector2, max_distance: float) -> void:
	var clamped_target = target.clamp(Vector2(x_min + width / 2.0, y_min + height / 2.0), Vector2(x_max - width / 2.0, y_max - height / 2.0))
	position = position.move_toward(clamped_target, max_distance)

# Move entity by displacement with physics collision detection and signalling
func move_parent_physics(movement: Vector2) -> KinematicCollision2D:
	var collision = move_and_collide(movement)
	if collision:
		body_collided.emit(collision.get_collider(), collision.get_normal())
	return collision

# Move entity toward target with physics collision detection
func move_parent_physics_toward(target: Vector2, max_distance: float) -> KinematicCollision2D:
	var direction: Vector2 = (target - position).normalized()
	var distance: float = minf(position.distance_to(target), max_distance)
	return move_and_collide(direction * distance)
