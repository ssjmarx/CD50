## emits score_gained to the game bus on collision with a valid target
class_name ScoreOnCollisionArm extends CDEntityComponent

@export var target_groups: Array[StringName]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var score_signals: Array[StringName] = [&"score_gained"]

var _points_guts: PointsGuts

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)
	for sig in score_signals:
		if game:
			game.ensure_signal(sig)
	
	_points_guts = null
	for child in entity.get_children():
		if child is PointsGuts:
			_points_guts = child
			break
	if _points_guts == null:
		push_warning("ScoreOnCollisionArm on '%s': no PointsGuts found — score will be 0" % entity.name)

func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return
	
	var points := 0
	if _points_guts:
		points = _points_guts.points
	
	if game:
		for sig in score_signals:
			game.emit_signal(sig, points)

func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
