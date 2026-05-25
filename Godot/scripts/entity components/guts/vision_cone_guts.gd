## defines a forward-facing vision cone that detects bodies
class_name VisionConeGuts extends CDEntityComponent

@export var cone_angle: float = 30.0
@export var cone_length: float = 200.0

@export_group("Listen Signals")
@export var aim_signals: Array[StringName] = [&"aim"]
@export var change_length_signals: Array[StringName] = [&"set_vision_range"]
@export var change_angle_signals: Array[StringName] = [&"set_vision_angle"]

@export_group("Emit Signals")
@export var body_entered_signals: Array[StringName] = [&"start_shooting"]
@export var body_exited_signals: Array[StringName] = [&"stop_shooting"]

var _detection_area: Area2D

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.STATE
	super._ready()

func _on_initialize() -> void:
	for sig in body_entered_signals:
		entity.ensure_signal(sig)
	for sig in body_exited_signals:
		entity.ensure_signal(sig)
	for sig in aim_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_aim)
	for sig in change_length_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_change_length)
	for sig in change_angle_signals:
		entity.ensure_signal(sig)
		entity.connect(sig, _on_change_angle)
	_create_cone()

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

func _on_aim(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if _detection_area:
		_detection_area.rotation = direction.angle() - entity.global_rotation

func _on_change_length(new_length: float) -> void:
	cone_length = new_length
	_rebuild_polygon()

func _on_change_angle(new_angle: float) -> void:
	cone_angle = new_angle
	_rebuild_polygon()

func _rebuild_polygon() -> void:
	if not _detection_area:
		return
	var polygon_node := _detection_area.get_child(0) as CollisionPolygon2D
	if polygon_node:
		polygon_node.polygon = _build_cone_points()

func _on_body_entered(body: Node2D) -> void:
	for sig in body_entered_signals:
		entity.emit_signal(sig, body)

func _on_body_exited(body: Node2D) -> void:
	for sig in body_exited_signals:
		entity.emit_signal(sig, body)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in aim_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_aim):
			entity.disconnect(sig, _on_aim)
	for sig in change_length_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_change_length):
			entity.disconnect(sig, _on_change_length)
	for sig in change_angle_signals:
		if entity.has_signal(sig) and entity.is_connected(sig, _on_change_angle):
			entity.disconnect(sig, _on_change_angle)
