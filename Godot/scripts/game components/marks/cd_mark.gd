# CDMark
# Base Area2D mark that detects body enter/exit and emits game bus signals
# Provides group filtering and auto-created collision shapes for subclasses

class_name CDMark extends Area2D

# --- exports ---

# radius for auto-created CircleShape2D
@export var shape_size: float = 16.0
# group whitelist for body filtering (empty = allow all)
@export var filter_groups: Array[StringName] = []

# game bus signals emitted on body enter/exit
@export_group("Emit Signals")
@export var on_entered: Array[StringName] = [&"body_entered"]
@export var on_exited: Array[StringName] = []

# game bus signals that swap the collision shape at runtime
@export_group("Listen Signals")
@export var on_set_shape: Array[StringName] = []

# --- state ---

# reference to the ancestor game controller
@onready var game: CDGame = CDGame.find_ancestor(self)

# auto-created collision shape (null if child already exists)
var _auto_shape: CollisionShape2D

# --- lifecycle ---

# set up collision shape and connect Area2D signals
func _ready() -> void:
	_ensure_collision_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# connect listen signals to game bus
func _on_initialize() -> void:
	for sig in on_set_shape:
		game.bus_connect(sig, _on_change_shape)

# --- collision shape ---

# attach a CollisionShape2D child or default to a circle
func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			return
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = shape_size
	add_child(shape)

# --- body detection ---

# emit entered signals for bodies that pass the group filter
func _on_body_entered(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_entered:
			game.bus_emit(sig, [body])

# emit exited signals for bodies that pass the group filter
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])

# --- runtime shape swap ---

# replace the auto-created collision shape
func _on_change_shape(new_shape: Shape2D) -> void:
	if _auto_shape:
		_auto_shape.shape = new_shape

# --- filtering ---

# return true if body matches any filter group (or all if no filter)
func _passes_filter(body: Node2D) -> bool:
	if filter_groups.is_empty():
		return true
	for g in filter_groups:
		if body.is_in_group(g):
			return true
	return false