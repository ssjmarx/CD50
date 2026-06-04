## CDEntity
## Base class for all V2 physical entities
## Accumulates movement requests, resolves physics, emits collision signals

class_name CDEntity extends CharacterBody2D

## --- Exports ---

## universal entity settings configured in editor
@export var groups: Array[StringName] = []
@export var collision_radius: float = 8.0
@export var collision_response: CDEnums.CollisionResponse = CDEnums.CollisionResponse.SLIDE
@export var lock_x: bool = false
@export var lock_y: bool = false
@export var clamp_to_bounds: bool = false
@export var bounds_margin: float = 0.0

## --- Internal State ---

## angular velocity for newtonian rotation
var angular_velocity: float = 0.0

## blackboard for shared state between components
var blackboard: Dictionary = {}

## accumulators: multiple components add to these per frame
var _accumulated_velocity_add: Vector2 = Vector2.ZERO
var _accumulated_angular_add: float = 0.0

## pending overrides: set beats add, last setter wins
var _velocity_set_pending: Variant = null
var _angular_set_pending: Variant = null
var _position_set_pending: Variant = null
var _position_add_pending: Variant = null
var _rotation_set_pending: Variant = null
var _rotation_add_pending: Variant = null

## per-frame signal emitter tracking (populated by bus_emit, cleared by CDUpdater)
var _signal_emitters: Dictionary = {}  # {StringName: Array}

## collision buffer: detected in physics, flushed by CDCollisionBuffer at priority 35
var _pending_collisions: Array = []
var _collision_buffer: CDCollisionBuffer

## entity state machine (ACTIVE, DEACTIVATING, INACTIVE)
var state: CDEnums.EntityState = CDEnums.EntityState.ACTIVE

## owning pool ref — null means this entity is not pooled
var pool

## cached references resolved at _ready
var game: CDGame
var _spawn_position: Vector2

## collision handler registry — guts components register custom responses here
var _collision_handlers: Array # [{layers: int, handler: Callable}] — 0 = catch-all

## prevents infinite collision loops in corners
const MAX_COLLISION_ITERATIONS: int = 4

## --- Setup ---

## fixed priority 30 (PHYSICS) — runs after components set velocity, before buffer flushes
func _ready() -> void:
	process_physics_priority = 30
	_spawn_position = global_position

	## define entity bus signals (typed, high-frequency)
	add_user_signal("collision", 	[{"name": "collider", "type": TYPE_OBJECT},
									{"name": "normal", "type": TYPE_VECTOR2}])
	add_user_signal("collided_by",	[{"name": "source", "type": TYPE_OBJECT},
									{"name": "normal", "type": TYPE_VECTOR2}])
	add_user_signal("request_deactivate", [])
	add_user_signal("entity_deactivating", [])
	add_user_signal("entity_activated", [])

	connect("request_deactivate", _on_request_deactivate)

	_create_default_collision_shape()

	## walk tree to find ancestor game
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDEntity '%s': no CDGame ancestor found." % name)
		return

	_collision_buffer = game.collision_buffer

	if game.collision_matrix:
		game.collision_matrix.configure(self)

	## register with all assigned groups and mark them dirty
	for group_name in groups:
		add_to_group(group_name)
		if game.group_registry:
			game.group_registry.mark_dirty(group_name)

## --- Physics Process ---

## the main job: resolve all pending movement requests, run physics, detect collisions
func _physics_process(delta: float) -> void:
	if state != CDEnums.EntityState.ACTIVE:
		return

	## clear last frame's emitter tracking
	_signal_emitters.clear()

	velocity += _accumulated_velocity_add
	if _velocity_set_pending != null:
		velocity = _velocity_set_pending

	angular_velocity += _accumulated_angular_add
	if _angular_set_pending != null:
		angular_velocity = _angular_set_pending

	## apply axis locks (paddles lock Y, some entities lock X)
	if lock_x:
		velocity.x = 0.0
	if lock_y:
		velocity.y = 0.0

	## iterate move_and_collide up to MAX_COLLISION_ITERATIONS per frame
	var remaining = velocity * delta
	for i in range(MAX_COLLISION_ITERATIONS):
		if remaining.length_squared() < 0.0001:
			break
		var collision = move_and_collide(remaining)
		if not collision:
			break

		var collider = collision.get_collider()
		if collider is CDEntity:
			_pending_collisions.append({"collider": collider, "normal": collision.get_normal()})

		## check for registered collision handler, fall back to default
		var handler = _find_collision_handler(collider)
		if handler.is_valid():
			remaining = handler.call(collision)
		else:
			remaining = _default_collision_response(collision)

	global_rotation += angular_velocity * delta

	## rotation overrides: snap or instant delta
	if _rotation_set_pending != null:
		global_rotation = _rotation_set_pending
	elif _rotation_add_pending != null:
		global_rotation += _rotation_add_pending

	## position overrides: teleport or offset (skips physics)
	if _position_set_pending != null:
		global_position = _position_set_pending
		reset_physics_interpolation()
	elif _position_add_pending != null:
		global_position += _position_add_pending
		reset_physics_interpolation()

	## clamp to game bounds if entity is constrained
	if clamp_to_bounds and game and game.game_bounds.has_area():
		var m := bounds_margin
		global_position.x = clampf(global_position.x, game.game_bounds.position.x + m, game.game_bounds.end.x - m)
		global_position.y = clampf(global_position.y, game.game_bounds.position.y + m, game.game_bounds.end.y - m)

	blackboard["position"] = global_position
	blackboard["rotation"] = global_rotation
	blackboard["velocity"] = velocity

	if _pending_collisions.size() > 0 and _collision_buffer:
		_collision_buffer.register_entity(self)

	## clear all accumulators and pending overrides for next frame
	_accumulated_velocity_add = Vector2.ZERO
	_accumulated_angular_add = 0.0
	_velocity_set_pending = null
	_angular_set_pending = null
	_position_set_pending = null
	_position_add_pending = null
	_rotation_set_pending = null
	_rotation_add_pending = null

## --- Velocity / Position / Rotation API ---

## override velocity entirely (beats add)
func request_velocity_set(vel: Vector2) -> void:
	_velocity_set_pending = vel

## add to velocity from a component (accumulates)
func request_velocity_add(vel: Vector2) -> void:
	_accumulated_velocity_add += vel

## override angular velocity entirely
func request_angular_set(ang: float) -> void:
	_angular_set_pending = ang

## add to angular velocity from a component
func request_angular_add(ang: float) -> void:
	_accumulated_angular_add += ang

## snap to a specific rotation (skips angular velocity)
func request_rotation_set(rot: float) -> void:
	_rotation_set_pending = rot

## instant fixed rotation delta
func request_rotation_add(rot_delta: float) -> void:
	_rotation_add_pending = rot_delta

## teleport to a position (skips physics)
func request_position_set(pos: Vector2) -> void:
	_position_set_pending = pos

## teleport by an offset
func request_position_add(offset: Vector2) -> void:
	_position_add_pending = offset

## --- Collision Flushing ---

## emit all queued collision + collided_by signals (called by CDCollisionBuffer at priority 35)
func flush_collisions() -> void:
	for col in _pending_collisions:
		var collider = col.collider
		var normal = col.normal
		emit_signal("collision", collider, normal)
		if is_instance_valid(collider) and collider.has_signal("collided_by"):
			collider.emit_signal("collided_by", self, -normal)
	_pending_collisions.clear()

## --- Lifecycle ---

## signal handler for request_deactivate
func _on_request_deactivate() -> void:
	deactivate()

## phase 1: immediate mark — entity stays functional until end of frame
func deactivate() -> void:
	if state != CDEnums.EntityState.ACTIVE:
		return
	state = CDEnums.EntityState.DEACTIVATING
	set_physics_process(false)
	blackboard.clear()
	call_deferred("_complete_deactivation")

## phase 2: deferred cleanup — runs at end of frame after all components finish
func _complete_deactivation() -> void:
	## disable collision shapes so dying entities stop blocking
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

	emit_signal("entity_deactivating")

	## remove from all groups and mark dirty for registry refresh
	for group_name in groups:
		remove_from_group(group_name)
		if game and game.group_registry:
			game.group_registry.mark_dirty(group_name)

	## return to pool or free
	if pool != null:
		visible = false
		state = CDEnums.EntityState.INACTIVE
		pool.release(self)
	else:
		state = CDEnums.EntityState.INACTIVE
		queue_free()

## wake an entity from the pool (re-enable physics, collisions, groups)
func activate() -> void:
	if state != CDEnums.EntityState.INACTIVE:
		return
	state = CDEnums.EntityState.ACTIVE
	
	blackboard.clear()

	## re-enable collision shapes
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", false)

	visible = true
	set_physics_process(true)

	## re-register with all groups
	for group_name in groups:
		add_to_group(group_name)
		if game and game.group_registry:
			game.group_registry.mark_dirty(group_name)

	emit_signal("entity_activated")

## --- Collision Shapes ---

## override collision shape with a circle (called by Faces at init)
func set_collision_circle(radius: float) -> void:
	_clear_collision_shapes()
	var shape = CircleShape2D.new()
	shape.radius = radius
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## override collision shape with a polygon (for vector-style entities)
func set_collision_polygon(points: PackedVector2Array) -> void:
	_clear_collision_shapes()
	var node = CollisionPolygon2D.new()
	node.polygon = points
	add_child(node)

## override collision shape with a rectangle (for paddles, bricks)
func set_collision_rect(width: float, height: float) -> void:
	_clear_collision_shapes()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## --- Universal Bus API ---

## bus connect
func bus_connect(signal_name: StringName, callable: Callable) -> void:
	if not has_signal(signal_name):
		add_user_signal(signal_name)
	connect(signal_name, callable)

## bus disconnect
func bus_disconnect(signal_name: StringName, callable: Callable) -> void:
	if has_signal(signal_name) and is_connected(signal_name, callable):
		disconnect(signal_name, callable)

## bus emit — zero-arg signal, automatically tracks self as emitter
func bus_emit(signal_name: StringName) -> void:
	if has_signal(signal_name):
		emit_signal(signal_name)
		## track emitter for this frame (entity bus: always self)
		if not _signal_emitters.has(signal_name):
			_signal_emitters[signal_name] = []
		_signal_emitters[signal_name].append(self)

## --- Utility ---

## walk up the tree to find the nearest CDEntity ancestor
static func find_ancestor(node: Node) -> CDEntity:
	var current = node.get_parent()
	while current:
		if current is CDEntity:
			return current
		current = current.get_parent()
	return null

## --- Internal ---

## create default circle collision shape from export
func _create_default_collision_shape() -> void:
	var shape = CircleShape2D.new()
	shape.radius = collision_radius
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## remove all existing collision shapes (before replacing)
func _clear_collision_shapes() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.queue_free()

## --- Collision Handler Registry ---

## register a custom collision handler for specific collider groups
## empty target_groups = catch-all (matches everything)
func register_collision_handler(target_groups: Array[StringName], handler: Callable) -> void:
	var layers: int = 0
	if target_groups.size() > 0 and game and game.collision_matrix:
		for group_name in target_groups:
			layers |= game.collision_matrix.get_layer_for_group(group_name)
	_collision_handlers.append({"layers": layers, "handler": handler})

## unregister a collision handler (called during component cleanup)
func unregister_collision_handler(handler: Callable) -> void:
	for i in range(_collision_handlers.size() - 1, -1, -1):
		if _collision_handlers[i]["handler"] == handler:
			_collision_handlers.remove_at(i)

## default collision response: SLIDE, BOUNCE, or STOP based on export
func _default_collision_response(collision: KinematicCollision2D) -> Vector2:
	var normal = collision.get_normal()
	match collision_response:
		CDEnums.CollisionResponse.SLIDE:
			velocity = velocity.slide(normal)
			return collision.get_remainder().slide(normal)
		CDEnums.CollisionResponse.BOUNCE:
			velocity = velocity.bounce(normal)
			return collision.get_remainder().bounce(normal)
		CDEnums.CollisionResponse.STOP:
			velocity = Vector2.ZERO
			return Vector2.ZERO
	return Vector2.ZERO

## find matching handler for a collider: specific layers first, then catch-all
func _find_collision_handler(collider) -> Callable:
	if collider == null or not is_instance_valid(collider):
		return Callable()

	var collider_layers: int = collider.collision_layer

	## first pass: specific handlers (layers != 0)
	for entry in _collision_handlers:
		var layers: int = entry["layers"]
		if layers == 0:
			continue
		if collider_layers & layers != 0:
			return entry["handler"]

	for entry in _collision_handlers:
		if entry["layers"] == 0:
			return entry["handler"]

	return Callable()
