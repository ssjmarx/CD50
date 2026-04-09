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

@export var width: int = 4
@export var height: int = 16
@export var x_min: float = 0.0
@export var x_max: float = 640.0
@export var y_min: float = 0.0
@export var y_max: float = 360.0
@export var lock_x: bool = false
@export var lock_y: bool = false

func _ready():
	left_joystick.connect(_on_left_joystick)
	mouse_position.connect(_on_mouse_position)
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)

func _on_left_joystick(direction: Vector2) -> void:
	if lock_x: direction.x = 0
	if lock_y: direction.y = 0
	move.emit(direction)

func _on_mouse_position(mouse_pos: Vector2) -> void:
	if lock_x: mouse_pos.x = self.position.x
	if lock_y: mouse_pos.y = self.position.y
	move_to.emit(mouse_pos)

func _on_button_pressed(_button: InputEvent) -> void:
	action.emit()

func _on_button_released(_button: InputEvent) -> void:
	end_action.emit()

func clamp_position() -> void:
	self.position.x = clampf(self.position.x, x_min + width / 2.0, x_max - width / 2.0)
	self.position.y = clampf(self.position.y, y_min + height / 2.0, y_max - height / 2.0)
