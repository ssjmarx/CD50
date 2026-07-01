## score_on_collision_arm.gd
## Produces: a score_gained event on the game bus when a valid collider is hit.
## Consumes: collision signals; entity.blackboard[points]; target_groups filter.
class_name ScoreOnCollisionArm extends CDEntityComponent

## if non-empty, only score on collision with these groups
@export var target_groups: Array[StringName]

@export_group("Blackboard Keys")
@export var scoring_keys: Array[StringName] = [&"score_gained"]

@export_group("Listen Signals")
@export var collision_signals: Array[StringName] = [&"collision"]

@export_group("Emit Signals")
@export var score_signals: Array[StringName] = [&"score_gained"]

## Set the interaction category before the base _ready arms lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTERACTION
	super._ready()

## connect collision signals, ensure game bus signals, find PointsGuts sibling
func _on_initialize() -> void:
	for sig in collision_signals:
		entity.connect(sig, _on_collision)
	for sig in score_signals:
		if game:
			game.ensure_signal(sig)

## emit score to game bus on valid collision
func _on_collision(collider: Node, _normal: Vector2) -> void:
	if not is_instance_valid(collider):
		return
	if not _is_valid_target(collider):
		return

	var points: int = entity.blackboard.get("points", 0)
	
	for key in scoring_keys:
		game.blackboard[key] = points
	
	if game:
		for sig in score_signals:
			game.bus_emit(sig)

## return true if target_groups is empty or collider is in one of them
func _is_valid_target(collider: Node) -> bool:
	if target_groups.is_empty():
		return true
	for group in target_groups:
		if collider.is_in_group(group):
			return true
	return false

## disconnect all collision signals on deactivation
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	for sig in collision_signals:
		if entity.is_connected(sig, _on_collision):
			entity.disconnect(sig, _on_collision)
