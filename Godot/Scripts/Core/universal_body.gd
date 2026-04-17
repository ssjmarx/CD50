# Universal base class for blackboard architecture. Routes signals between components, provides position clamping and axis locking.
class_name UniversalBody extends CharacterBody2D

# Signals from components (Brains listen, emit to body)
signal left_joystick(direction: Vector2)
signal right_joystick(direction: Vector2)
signal mouse_position(position: Vector2)
signal button_pressed(button: InputEvent)
signal button_released(button: InputEvent)

# Signals from router (Components listen after processing)
signal move(direction: Vector2)
signal move_to(position: Vector2)
signal action(button: InputEvent)
signal end_action(button: InputEvent)
signal shoot(button: InputEvent)
signal end_shoot(button: InputEvent)
signal thrust(button: InputEvent)
signal end_thrust(button: InputEvent)
signal aim(direction: Vector2)
signal aim_at(position: Vector2)
signal body_collided(collider: Node, normal: Vector2)

# Entity dimensions for collision and clamping
@export var width: int = 4
@export var height: int = 16

# Position constraints (clamping bounds)
@export var x_min: float = 0.0
@export var x_max: float = 640.0
@export var y_min: float = 0.0
@export var y_max: float = 360.0

# Movement axis locks (disable movement on locked axes)
@export var lock_x: bool = false
@export var lock_y: bool = false

# Collision groups for CollisionMatrix configuration (first is primary layer)
@export var collision_groups: Array[String] = []

func _ready() -> void:
	# Run after all Legs and friction components
	process_priority = 100
	process_physics_priority = 100
	
	# Connect input signals to router functions
	left_joystick.connect(_on_left_joystick)
	right_joystick.connect(_on_right_joystick)
	mouse_position.connect(_on_mouse_position)
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)

func _physics_process(delta: float) -> void:
	# Apply shared velocity to position (priority 100, runs after Legs)
	move_parent_physics(velocity * delta)

func _on_left_joystick(direction: Vector2) -> void:
	# Apply axis locks before emitting
	if lock_x: direction.x = 0
	if lock_y: direction.y = 0
	move.emit(direction)

func _on_right_joystick(direction: Vector2) -> void:
	# Right stick is for aiming, no axis locks
	aim.emit(direction)

func _on_mouse_position(mouse_pos: Vector2) -> void:
	# Lock axes to current position if locked
	if lock_x: mouse_pos.x = self.position.x
	if lock_y: mouse_pos.y = self.position.y
	# Emit both movement and aim signals
	move_to.emit(mouse_pos)
	aim_at.emit(mouse_pos)

func _on_button_pressed(button: InputEvent) -> void:
	# Generic action event
	action.emit()
	
	# Map specific buttons to their events
	if button.is_action("button_r"):
		shoot.emit()
	
	if button.is_action("button_l"):
		thrust.emit()

func _on_button_released(button: InputEvent) -> void:
	# Generic action release event
	end_action.emit()
	
	# Map specific buttons to their release events
	if button.is_action("button_r"):
		end_shoot.emit()
	
	if button.is_action("button_l"):
		end_thrust.emit()

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
		velocity = velocity.bounce(collision.get_normal())
		body_collided.emit(collision.get_collider(), collision.get_normal())
	return collision

# Move entity toward target with physics collision detection
func move_parent_physics_toward(target: Vector2, max_distance: float) -> KinematicCollision2D:
	var direction := (target - position).normalized()
	var distance := minf(position.distance_to(target), max_distance)
	return move_and_collide(direction * distance)
