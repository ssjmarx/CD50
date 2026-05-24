## emits signals on body entered and exited
class_name CDMark extends Area2D

@export var shape_size: float = 16.0
@export var filter_groups: Array[StringName] = []

@export_group("Emit Signals")
@export var on_entered: Array[StringName] = [&"body_entered"]
@export var on_exited: Array[StringName] = []

@export_group("Listen Signals")
@export var on_set_shape: Array[StringName] = []

@onready var game: CDGame = CDGame.find_ancestor(self)

var _auto_shape: CollisionShape2D

func _ready() -> void:
	_ensure_collision_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_initialize() -> void:
	for sig in on_set_shape:
		game.bus_connect(sig, _on_change_shape)

## attach a collisionshape2d or default to a circle
func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = shape_size
	add_child(shape)

func _on_body_entered(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_entered:
			game.bus_emit(sig, [body])

func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])

func _on_change_shape(new_shape: Shape2D) -> void:
	if _auto_shape:
		_auto_shape.shape = new_shape

func _passes_filter(body: Node2D) -> bool:
	if filter_groups.is_empty():
		return true
	for g in filter_groups:
		if body.is_in_group(g):
			return true
	return false
