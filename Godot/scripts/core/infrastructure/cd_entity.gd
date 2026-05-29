## base class for all V2 physical entities
class_name CDEntity extends CharacterBody2D

## universal entity settings
@export var groups: Array[StringName] = []
@export var collision_radius: float = 8.0
@export var collision_response: CDEnums.CollisionResponse = CDEnums.CollisionResponse.SLIDE
@export var lock_x: bool = false
@export var lock_y: bool = false
@export var clamp_to_bounds: bool = false
@export var bounds_margin: float = 0.0

## angular velocity component, provides for newtonian rotation
var angular_velocity: float = 0.0

## accumulators for movement resolution
var _accumulated_velocity_add: Vector2 = Vector2.ZERO
var _accumulated_angular_add: float = 0.0

## null is not set, vector2 or float is set
var _velocity_set_pending: Variant = null
var _angular_set_pending: Variant = null
var _position_set_pending: Variant = null
var _position_add_pending: Variant = null
var _rotation_set_pending: Variant = null
var _rotation_add_pending: Variant = null

## deferred collision resolution
var _pending_collisions: Array = []
var _collision_buffer: CDCollisionBuffer

## tfw state machine
var state: CDEnums.EntityState = CDEnums.EntityState.ACTIVE

## owning pool, if null means that CDEntity is not pooled
var pool

## universal references
var game: CDGame
var _spawn_position: Vector2

## collision handler registry — guts components register here to override physics
var _collision_handlers: Array # [{layers: int, handler: Callable}] — 0 = catch-all

## prevents infinite collisions in corners
const MAX_COLLISION_ITERATIONS: int = 4

## priority is always 30 for CDEntity
func _ready() -> void:
	process_physics_priority = 30
	
	_spawn_position = global_position
	
	add_user_signal("collision", 	[{"name": "collider", "type": TYPE_OBJECT},
									{"name": "normal", "type": TYPE_VECTOR2}])
	add_user_signal("collided_by",	[{"name": "source", "type": TYPE_OBJECT},
									{"name": "normal", "type": TYPE_VECTOR2}])
	add_user_signal("request_deactivate", [])
	add_user_signal("entity_deactivating", [])
	add_user_signal("entity_activated", [])
	add_user_signal("moved",	[{"name": "old_pos", "type": TYPE_VECTOR2},
							   	{"name": "new_pos", "type": TYPE_VECTOR2}])
	add_user_signal("rotated", 	[{"name": "old_rot", "type": TYPE_FLOAT},
								{"name": "new_rot", "type": TYPE_FLOAT}])
	
	connect("request_deactivate", _on_request_deactivate)
	
	_create_default_collision_shape()
	
	game = CDGame.find_ancestor(self)
	if game == null:
		push_error("CDEntity '%s': no CDGame ancestor found." % name)
		return
	
	_collision_buffer = game.collision_buffer
	
	if game.collision_matrix:
		game.collision_matrix.configure(self)
	
	for group_name in groups:
		add_to_group(group_name)
		if game.group_registry:
			game.group_registry.mark_dirty(group_name)

## the main job of CDEntity
func _physics_process(delta: float) -> void:
	if state != CDEnums.EntityState.ACTIVE:
		return
	
	# combine all movement requests
	velocity += _accumulated_velocity_add
	if _velocity_set_pending != null:
		velocity = _velocity_set_pending
	
	angular_velocity += _accumulated_angular_add
	if _angular_set_pending != null:
		angular_velocity = _angular_set_pending
	
	# apply axis locks
	if lock_x:
		velocity.x = 0.0
	if lock_y:
		velocity.y = 0.0
	
	# get your spot
	var old_position = global_position
	var old_rotation = global_rotation
	
	# move and collide
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
		
		var handler = _find_collision_handler(collider)
		if handler.is_valid():
			remaining = handler.call(collision)
		else:
			remaining = _default_collision_response(collision)
	
	# rotation
	global_rotation += angular_velocity * delta
	
	# snap
	if _rotation_set_pending != null:
		global_rotation = _rotation_set_pending
	elif _rotation_add_pending != null:
		global_rotation += _rotation_add_pending
	
	# teleport
	if _position_set_pending != null:
		global_position = _position_set_pending
	elif _position_add_pending != null:
		global_position += _position_add_pending
	
	# clamp
	if clamp_to_bounds and game and game.game_bounds.has_area():
		var m := bounds_margin
		global_position.x = clampf(global_position.x, game.game_bounds.position.x + m, game.game_bounds.end.x - m)
		global_position.y = clampf(global_position.y, game.game_bounds.position.y + m, game.game_bounds.end.y - m)

	# emit
	if old_position != global_position:
		emit_signal("moved", old_position, global_position)
	if old_rotation != global_rotation:
		emit_signal("rotated", old_rotation, global_rotation)
	
	# register collisions
	if _pending_collisions.size() > 0 and _collision_buffer:
		_collision_buffer.register_entity(self)
	
	# clear accumulators
	_accumulated_velocity_add = Vector2.ZERO
	_accumulated_angular_add = 0.0
	
	# clear setters
	_velocity_set_pending = null
	_angular_set_pending = null
	_position_set_pending = null
	_position_add_pending = null
	_rotation_set_pending = null
	_rotation_add_pending = null

## override velocity
func request_velocity_set(vel: Vector2) -> void:
	_velocity_set_pending = vel

## add to velocity
func request_velocity_add(vel: Vector2) -> void:
	_accumulated_velocity_add += vel

## override angular velocity
func request_angular_set(ang: float) -> void:
	_angular_set_pending = ang

## add to angular velocity
func request_angular_add(ang: float) -> void:
	_accumulated_angular_add += ang

## snap to rotation
func request_rotation_set(rot: float) -> void:
	_rotation_set_pending = rot

## instant fixed rotation
func request_rotation_add(rot_delta: float) -> void:
	_rotation_add_pending = rot_delta

## teleport to position
func request_position_set(pos: Vector2) -> void:
	_position_set_pending = pos

## teleport by reference
func request_position_add(offset: Vector2) -> void:
	_position_add_pending = offset

## perform all buffered collisions
func flush_collisions() -> void:
	for col in _pending_collisions:
		var collider = col.collider
		var normal = col.normal
		emit_signal("collision", collider, normal)
		if is_instance_valid(collider) and collider.has_signal("collided_by"):
			collider.emit_signal("collided_by", self, -normal)
	_pending_collisions.clear()

## signal handler for request_deactivate
func _on_request_deactivate() -> void:
	deactivate()

## phase 1: immediate mark — entity stays fully functional until end of frame
func deactivate() -> void:
	if state != CDEnums.EntityState.ACTIVE:
		return
	state = CDEnums.EntityState.DEACTIVATING
	set_physics_process(false)
	call_deferred("_complete_deactivation")

## phase 2: deferred cleanup — runs at priority 99 (end of frame)
func _complete_deactivation() -> void:
	# disable collisions
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", true)

	# notify components — disconnect signals, reset state
	emit_signal("entity_deactivating")

	# clean up groups
	for group_name in groups:
		remove_from_group(group_name)
		if game and game.group_registry:
			game.group_registry.mark_dirty(group_name)

	# return to pool or free
	if pool != null:
		visible = false
		state = CDEnums.EntityState.INACTIVE
		pool.release(self)
	else:
		state = CDEnums.EntityState.INACTIVE
		queue_free()

## wake from pool
func activate() -> void:
	if state != CDEnums.EntityState.INACTIVE:
		return
	state = CDEnums.EntityState.ACTIVE

	# enable collisions
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", false)

	visible = true
	set_physics_process(true)

	# register with groups
	for group_name in groups:
		add_to_group(group_name)
		if game and game.group_registry:
			game.group_registry.mark_dirty(group_name)

	# notify components
	emit_signal("entity_activated")

## override collision shape with circle
func set_collision_circle(radius: float) -> void:
	_clear_collision_shapes()
	var shape = CircleShape2D.new()
	shape.radius = radius
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## override collision shape with polygon
func set_collision_polygon(points: PackedVector2Array) -> void:
	_clear_collision_shapes()
	var node = CollisionPolygon2D.new()
	node.polygon = points
	add_child(node)

## override collision shape with rectangle
func set_collision_rect(width: float, height: float) -> void:
	_clear_collision_shapes()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## ensures a user signal exists on this entity
func ensure_signal(signal_name: StringName) -> void:
	if not has_signal(signal_name):
		add_user_signal(signal_name)

## find CDEntity ancestor
static func find_ancestor(node: Node) -> CDEntity:
	var current = node.get_parent()
	while current:
		if current is CDEntity:
			return current
		current = current.get_parent()
	return null

## default collision shape is a circle
func _create_default_collision_shape() -> void:
	var shape = CircleShape2D.new()
	shape.radius = collision_radius
	var node = CollisionShape2D.new()
	node.shape = shape
	add_child(node)

## get rid of collision shape
func _clear_collision_shapes() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.queue_free()

## register a custom collision handler for specific collider groups.
## empty target_groups = catch-all (layers = 0, matches everything).
## resolves group names to layer bitmask at registration time via collision matrix.
func register_collision_handler(target_groups: Array[StringName], handler: Callable) -> void:
	var layers: int = 0
	if target_groups.size() > 0 and game and game.collision_matrix:
		for group_name in target_groups:
			layers |= game.collision_matrix.get_layer_for_group(group_name)
	_collision_handlers.append({"layers": layers, "handler": handler})

## unregister a collision handler (called during cleanup)
func unregister_collision_handler(handler: Callable) -> void:
	for i in range(_collision_handlers.size() - 1, -1, -1):
		if _collision_handlers[i]["handler"] == handler:
			_collision_handlers.remove_at(i)

## default collision handling, used in most cases
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

## find matching handler for this collider using layer bitmask
func _find_collision_handler(collider) -> Callable:
	if collider == null or not is_instance_valid(collider):
		return Callable()
	
	var collider_layers: int = collider.collision_layer
	
	# check specific handlers first (layers != 0)
	for entry in _collision_handlers:
		var layers: int = entry["layers"]
		if layers == 0:
			continue  # skip catch-alls in first pass
		if collider_layers & layers != 0:
			return entry["handler"]
	
	# check catch-all handlers (layers == 0)
	for entry in _collision_handlers:
		if entry["layers"] == 0:
			return entry["handler"]
	
	return Callable()
