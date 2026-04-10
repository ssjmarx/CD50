# universal script for "blackboard" architecture.  contains signals for routing between components, and some universal features like axis lock and positional constraints.

extends CharacterBody2D

signal left_joystick(direction: Vector2)
signal mouse_position(position: Vector2)
signal button_pressed(button: InputEvent)
signal button_released(button: InputEvent)
signal move(direction: Vector2)
signal move_to(position: Vector2)
signal action(button: InputEvent)
signal end_action(button: InputEvent)
signal shoot(button: InputEvent)
signal end_shoot(button: InputEvent)
signal thrust(button: InputEvent)
signal end_thrust(button: InputEvent)

@export var width: int = 4
@export var height: int = 16
@export var x_min: float = 0.0
@export var x_max: float = 640.0
@export var y_min: float = 0.0
@export var y_max: float = 360.0
@export var lock_x: bool = false
@export var lock_y: bool = false

func _ready():
	process_priority = 100
	process_physics_priority = 100
	
	left_joystick.connect(_on_left_joystick)
	mouse_position.connect(_on_mouse_position)
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)

func _physics_process(delta: float) -> void:
	move_parent(velocity * delta)

func _on_left_joystick(direction: Vector2) -> void:
	if lock_x: direction.x = 0
	if lock_y: direction.y = 0
	move.emit(direction)

func _on_mouse_position(mouse_pos: Vector2) -> void:
	if lock_x: mouse_pos.x = self.position.x
	if lock_y: mouse_pos.y = self.position.y
	move_to.emit(mouse_pos)

func _on_button_pressed(button: InputEvent) -> void:
	action.emit()
	
	if button.is_action("button_r"):
		shoot.emit()
	
	if button.is_action("button_l"):
		thrust.emit()

func _on_button_released(button: InputEvent) -> void:
	end_action.emit()
	
	if button.is_action("button_r"):
		end_shoot.emit()
	
	if button.is_action("button_l"):
		end_thrust.emit()

func move_parent(movement: Vector2) -> void:
	position.x = clampf(position.x + movement.x, x_min + width / 2.0, x_max - width / 2.0)
	position.y = clampf(position.y + movement.y, y_min + height / 2.0, y_max - height / 2.0)

func move_parent_toward(target: Vector2, max_distance: float) -> void:
	var clamped_target = target.clamp(Vector2(x_min + width / 2.0, y_min + height / 2.0), Vector2(x_max - width / 2.0, y_max - height / 2.0))
	position = position.move_toward(clamped_target, max_distance)

func move_parent_physics(movement: Vector2) -> KinematicCollision2D:
	return move_and_collide(movement)

func move_parent_physics_toward(target: Vector2, max_distance: float) -> KinematicCollision2D:
	var direction := (target - position).normalized()
	var distance := minf(position.distance_to(target), max_distance)
	return move_and_collide(direction * distance)
