## CDMark
## Base Area2D mark that detects body enter/exit and emits zero-arg signals
## Emits on both the game bus and the entering/exiting entity's bus.
## Provides group filtering and auto-created collision shapes for subclasses.
## Writes detected body to game blackboard before emitting.

class_name CDMark extends Area2D

## --- exports ---

## groups this mark belongs to (registered in Godot's group system)
@export var groups: Array[StringName] = []
## radius for auto-created CircleShape2D
@export var shape_size: float = 16.0
## group whitelist for body filtering (empty = allow all)
@export var filter_groups: Array[StringName] = []

@export_group("Blackboard Keys")
## key for writing the last entered body to game blackboard (Node2D)
@export var entered_body_key: StringName = &"mark_entered_body"
## key for writing the last exited body to game blackboard (Node2D)
@export var exited_body_key: StringName = &"mark_exited_body"
## key for reading a new shape from game blackboard (Shape2D)
@export var shape_key: StringName = &"mark_shape"

## game bus signals emitted on body enter/exit (zero-arg)
@export_group("Emit Game Bus Signals")
@export var on_entered: Array[StringName] = [&"body_entered"]
@export var on_exited: Array[StringName] = []

## entity bus signals emitted on the body that enters/exits (zero-arg)
## Allows a mark to trigger behavior directly on the entity that touched it
@export_group("Emit Entity Bus Signals")
@export var on_entered_entity: Array[StringName] = []
@export var on_exited_entity: Array[StringName] = []

## game bus signals that swap the collision shape at runtime
@export_group("Listen Signals")
@export var on_set_shape: Array[StringName] = []

## --- state ---

## reference to the ancestor game controller
@onready var game: CDGame = CDGame.find_ancestor(self)

## auto-created collision shape (null if child already exists)
var _auto_shape: CollisionShape2D

## --- lifecycle ---

## register groups, set up collision shape, connect Area2D signals
func _ready() -> void:
	for g in groups:
		add_to_group(g)
	_ensure_collision_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if game and game.collision_matrix:
		game.collision_matrix.configure(self)
	call_deferred("_on_initialize")

## connect listen signals to game bus
func _on_initialize() -> void:
	for sig in on_set_shape:
		game.bus_connect(sig, _on_change_shape)

## --- collision shape ---

## attach a CollisionShape2D child or default to a circle
func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			_auto_shape = child
			return
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = shape_size
	add_child(shape)
	_auto_shape = shape

## --- body detection ---

## write body to blackboard, emit game bus signals, and emit entity bus signals
func _on_body_entered(body: Node2D) -> void:
	#print("body entered")
	if _passes_filter(body):
		#print("body being counted")
		game.blackboard[entered_body_key] = body
		for sig in on_entered:
			game.bus_emit(sig)
		
		# Emit on the entering entity's bus if it is a CDEntity
		if body is CDEntity:
			#print("entity detected")
			for sig in on_entered_entity:
				body.bus_emit(sig)
				#print("emitted on entity")

## write body to blackboard, emit game bus signals, and emit entity bus signals
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		game.blackboard[exited_body_key] = body
		for sig in on_exited:
			game.bus_emit(sig)
			
		# Emit on the exiting entity's bus if it is a CDEntity
		if body is CDEntity:
			for sig in on_exited_entity:
				body.bus_emit(sig)

## --- runtime shape swap ---

## read new shape from game blackboard and apply
func _on_change_shape() -> void:
	if _auto_shape:
		var new_shape: Shape2D = game.blackboard.get(shape_key, null)
		if new_shape:
			_auto_shape.shape = new_shape

## --- filtering ---

## return true if body matches any filter group (or all if no filter)
func _passes_filter(body: Node2D) -> bool:
	if filter_groups.is_empty():
		return true
	for g in filter_groups:
		if body.is_in_group(g):
			return true
	return false
