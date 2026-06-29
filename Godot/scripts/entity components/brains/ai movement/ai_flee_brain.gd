## ai_flee_brain.gd
## Produces: move direction away from the nearest threat in threat_groups (written to blackboard), stopping beyond flee_distance.
## Consumes: threat_groups via game.group_registry; move_key blackboard key.
class_name AIFleeBrain extends CDEntityComponent

## groups to search for threats
@export var threat_groups: Array[StringName] = [&"player"]

## stop fleeing when farther than this from threat
@export var flee_distance: float = 150.0

## seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

## random offset added to threat position for imprecision
@export var targeting_noise: float = 0.0

@export var move_key: StringName = &"move_direction"

## timer for throttled updates
var _update_timer: float = 0.0

## cached direction for throttled frames
var _last_direction: Vector2 = Vector2.ZERO

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## emit move direction each frame, recalculate target on interval
func _physics_process(delta: float) -> void:
	## if throttled, emit cached direction until interval expires
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			entity.blackboard[move_key] = _last_direction
			return
		_update_timer = 0.0

	## find nearest threat across all groups
	var nearest := _find_nearest()
	if nearest == null:
		_last_direction = Vector2.ZERO
		entity.blackboard[move_key] = _last_direction
		return

	var threat_pos := _apply_noise(nearest.global_position)
	var distance := entity.global_position.distance_to(threat_pos)

	## stop fleeing if far enough away
	if distance > flee_distance:
		_last_direction = Vector2.ZERO
		entity.blackboard[move_key] = _last_direction
		return

	_last_direction = threat_pos.direction_to(entity.global_position)
	entity.blackboard[move_key] = _last_direction

## search all threat groups for the nearest entity
func _find_nearest() -> CDEntity:
	for group in threat_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			return candidate
	return null

## add random offset to target position if noise is configured
func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

## Reset the throttle timer and cached direction on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_update_timer = 0.0
	_last_direction = Vector2.ZERO
