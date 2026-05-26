## emits score_gained to the game bus when this entity dies
class_name ScoreOnDeathArm extends CDEntityComponent

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

@export_group("Emit Signals")
@export var score_signals: Array[StringName] = [&"score_gained"]

var _points_guts: PointsGuts

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

func _on_initialize() -> void:
	for sig in death_signals:
		entity.connect(sig, _on_death)
	for sig in score_signals:
		if game:
			game.ensure_signal(sig)
	
	_points_guts = null
	for child in entity.get_children():
		if child is PointsGuts:
			_points_guts = child
			break
	if _points_guts == null:
		push_warning("ScoreOnDeathArm on '%s': no PointsGuts found — score will be 0" % entity.name)

func _on_death() -> void:
	var points := 0
	if _points_guts:
		points = _points_guts.points
	
	if game:
		for sig in score_signals:
			game.emit_signal(sig, points)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		if entity.is_connected(sig, _on_death):
			entity.disconnect(sig, _on_death)
