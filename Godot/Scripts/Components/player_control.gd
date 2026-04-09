# universal player control node.  emits controller inputs to its parent

extends Node

var using_mouse: bool = false

@onready var parent = get_parent()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		parent.mouse_position.emit(event.position)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			parent.button_pressed.emit(event)
		if event.is_released():
			parent.button_released.emit(event)


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Vector2.ZERO
	direction.y = Input.get_axis("button_up", "button_down")
	direction.x = Input.get_axis("button_left", "button_right")
	parent.left_joystick.emit(direction)
