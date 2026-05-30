# ScoreOnDeathArm
# Emits score_gained to the game bus when this entity dies
# Reads point value from a sibling PointsGuts component

class_name ScoreOnDeathArm extends CDEntityComponent

@export_group("Listen Signals")
@export var death_signals: Array[StringName] = [&"zero_health"]

@export_group("Emit Signals")
@export var score_signals: Array[StringName] = [&"score_gained"]

# cached reference to sibling PointsGuts
var _points_guts: PointsGuts

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect death signals, ensure game bus signals, find PointsGuts sibling
func _on_initialize() -> void:
	for sig in death_signals:
		entity.connect(sig, _on_death)
	for sig in score_signals:
		if game:
			game.ensure_signal(sig)

	# search for PointsGuts sibling
	_points_guts = null
	for child in entity.get_children():
		if child is PointsGuts:
			_points_guts = child
			break
	if _points_guts == null:
		push_warning("ScoreOnDeathArm on '%s': no PointsGuts found — score will be 0" % entity.name)

# read points from PointsGuts and emit score on game bus
func _on_death() -> void:
	var points := 0
	if _points_guts:
		points = _points_guts.points

	# emit score on game bus
	if game:
		for sig in score_signals:
			game.emit_signal(sig, points)

# disconnect all death signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in death_signals:
		if entity.is_connected(sig, _on_death):
			entity.disconnect(sig, _on_death)
