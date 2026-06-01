# ScoreOnCollisionArm
# Emits score_gained to the game bus on collision with a valid target
# Reads point value from a sibling PointsGuts component

class_name ScoreOnCollisionArm extends CDEntityComponent

# if non-empty, only score on collision with these groups
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var scoring_keys: Array[StringName] = [&"score_gained"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var score_signals: Array[StringName] = [&"score_gained"]

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

# connect collision signals, ensure game bus signals, find PointsGuts sibling
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)
	for sig in score_signals:
		if game:
			game.ensure_signal(sig)

# emit score to game bus on valid collision
func _on_collision(collider: CDEntity, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	# read points from entity blackboard
	var points: int = entity.blackboard.get("points", 0)
	
	# write to game blackboard
	for key in scoring_keys:
		game.blackboard[key] = points
	
	# emit score on game bus
	if game:
		for sig in score_signals:
			game.bus_emit(sig)

# return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: CDEntity) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

# disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
