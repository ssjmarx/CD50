# simple node that turns input into movement, or moves towards a mouse position

extends Node

@export var mouse_enabled: bool = false
@export var acceleration: int = 200

var input: Vector2
var target: Vector2
var using_mouse: bool = false

@onready var parent = get_parent()

func _physics_process(delta):
	if not using_mouse:
		parent.velocity += input * acceleration * delta
	else:
		var direction: Vector2 = (target - parent.position).normalized()
		parent.velocity += direction * acceleration * delta

func _ready() -> void:
	parent.move.connect(_on_move)
	parent.move_to.connect(_on_move_to)

func _on_move(direction: Vector2) -> void:
	input = direction
	if direction != Vector2.ZERO:
		using_mouse = false

func _on_move_to(mouse_pos: Vector2) -> void:
	if mouse_enabled:
		target = mouse_pos
		using_mouse = true
