# VisionConeGuts
# Defines a forward-facing vision cone that detects bodies
# Creates a dynamic Area2D with CollisionPolygon2D
# Reads aim direction, cone length, and cone angle from entity blackboard
# Writes detected body to entity blackboard on enter/exit

class_name VisionConeGuts extends CDEntityComponent

# --- exports ---

# total cone angle in degrees
@export var cone_angle: float = 30.0
# cone reach distance in pixels
@export var cone_length: float = 200.0

@export_group("Blackboard Keys")
# key to read aim direction from (Vector2)
@export var aim_key: StringName = &"aim_direction"
# key to read cone length changes from (float)
@export var length_key: StringName = &"vision_range"
# key to read cone angle changes from (float)
@export var angle_key: StringName = &"vision_angle"
# key to write detected body to (Node2D)
@export var target_key: StringName = &"detected_body"

# signals that trigger aim direction check
@export_group("Listen Signals")
@export var aim_signals: Array[StringName] = [&"aim"]
# signals that trigger length reconfiguration
@export var change_length_signals: Array[StringName] = [&"set_vision_range"]
# signals that trigger angle reconfiguration
@export var change_angle_signals: Array[StringName] = [&"set_vision_angle"]

# emitted when a body enters the cone
@export_group("Emit Signals")
@export var body_entered_signals: Array[StringName] = [&"start_shooting"]
# emitted when a body exits the cone
@export var body_exited_signals: Array[StringName] = [&"stop_shooting"]

# --- state ---

var _detection_area: Area2D
var _prev_length: float = 0.0
var _prev_angle: float = 0.0

# --- lifecycle ---

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in aim_signals:
		entity.bus_connect(sig, _on_aim)
	for sig in change_length_signals:
		entity.bus_connect(sig, _on_change_length)
	for sig in change_angle_signals:
		entity.bus_connect(sig, _on_change_angle)
	
	_prev_length = cone_length
	_prev_angle = cone_angle
	_create_cone()

# --- cone construction ---

func _create_cone() -> void:
	_detection_area = Area2D.new()
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = _build_cone_points()
	_detection_area.add_child(polygon)
	add_child(_detection_area)
	_detection_area.body_entered.connect(_on_body_entered)
	_detection_area.body_exited.connect(_on_body_exited)

func _build_cone_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_angle := deg_to_rad(cone_angle) / 2.0
	var segments := 8
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t := i / float(segments)
		var a := -half_angle + t * deg_to_rad(cone_angle)
		points.append(Vector2(cos(a), sin(a)) * cone_length)
	return points

# --- signal handlers ---

# read aim direction from blackboard and rotate cone
func _on_aim() -> void:
	var direction: Vector2 = entity.blackboard.get(aim_key, Vector2.ZERO)
	if direction == Vector2.ZERO:
		return
	if _detection_area:
		_detection_area.rotation = direction.angle() - entity.global_rotation

# read new length from blackboard and rebuild polygon
func _on_change_length() -> void:
	var new_length: float = entity.blackboard.get(length_key, cone_length)
	if new_length != _prev_length:
		cone_length = new_length
		_prev_length = new_length
		_rebuild_polygon()

# read new angle from blackboard and rebuild polygon
func _on_change_angle() -> void:
	var new_angle: float = entity.blackboard.get(angle_key, cone_angle)
	if new_angle != _prev_angle:
		cone_angle = new_angle
		_prev_angle = new_angle
		_rebuild_polygon()

# --- helpers ---

func _rebuild_polygon() -> void:
	if not _detection_area:
		return
	var polygon_node := _detection_area.get_child(0) as CollisionPolygon2D
	if polygon_node:
		polygon_node.polygon = _build_cone_points()

# --- detection callbacks ---

# write body to blackboard and emit zero-arg signal
func _on_body_entered(body: Node2D) -> void:
	entity.blackboard[target_key] = body
	for sig in body_entered_signals:
		entity.bus_emit(sig)

# write body to blackboard and emit zero-arg signal
func _on_body_exited(body: Node2D) -> void:
	entity.blackboard[target_key] = body
	for sig in body_exited_signals:
		entity.bus_emit(sig)

# --- cleanup ---

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	entity.blackboard.erase(target_key)
	for sig in aim_signals:
		entity.bus_disconnect(sig, _on_aim)
	for sig in change_length_signals:
		entity.bus_disconnect(sig, _on_change_length)
	for sig in change_angle_signals:
		entity.bus_disconnect(sig, _on_change_angle)