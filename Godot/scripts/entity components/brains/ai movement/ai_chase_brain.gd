## ai_chase_brain.gd
## Produces: move direction and distance toward the nearest target in target_groups (written to blackboard), stopping within stop_distance.
## Consumes: target_groups via game.group_registry; move_key/distance_key blackboard keys.
class_name AIChaseBrain extends CDEntityComponent

## locks movement and distance calculations to a specific axis
enum AxisMode { NONE, X, Y }

## groups to search for chase targets
@export var target_groups: Array[StringName] = [&"enemies"]

## stop emitting move when this close to target
@export var stop_distance: float = 10.0

## seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

## random offset added to target position for imprecision
@export var targeting_noise: float = 0.0

## restricts movement intent to a single axis (useful for Pong paddles)
@export var axis_mode: AxisMode = AxisMode.NONE

@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

## timer for throttled updates
var _update_timer: float = 0.0

## cached direction for throttled frames
var _last_direction: Vector2 = Vector2.ZERO
## cached distance for throttled frames
var _last_distance: float = 0.0

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## emit move direction each frame, recalculate target on interval
func _physics_process(delta: float) -> void:
	## if throttled, write cached direction to the blackboard
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			entity.blackboard[move_key] = _last_direction
			entity.blackboard[distance_key] = _last_distance
			return
		_update_timer = 0.0

	## find nearest target across all groups
	var target := _find_nearest()
	if target == null:
		_last_direction = Vector2.ZERO
		_last_distance = 0.0
		entity.blackboard[move_key] = _last_direction
		entity.blackboard[distance_key] = _last_distance
		return

	var target_pos := _apply_noise(target.global_position)
	var distance := 0.0
	var direction := Vector2.ZERO

	## calculate distance and direction based on axis lock mode
	match axis_mode:
		AxisMode.X:
			var delta_x := target_pos.x - entity.global_position.x
			distance = abs(delta_x)
			if distance > 0.0:
				direction = Vector2(sign(delta_x), 0.0)
		AxisMode.Y:
			var delta_y := target_pos.y - entity.global_position.y
			distance = abs(delta_y)
			if distance > 0.0:
				direction = Vector2(0.0, sign(delta_y))
		AxisMode.NONE:
			distance = entity.global_position.distance_to(target_pos)
			direction = entity.global_position.direction_to(target_pos)

	## stop if within range
	if distance <= stop_distance:
		_last_direction = Vector2.ZERO
		_last_distance = 0.0
		entity.blackboard[move_key] = _last_direction
		entity.blackboard[distance_key] = _last_distance
		return

	## emit direction toward target
	_last_direction = direction
	_last_distance = distance
	entity.blackboard[move_key] = _last_direction
	entity.blackboard[distance_key] = _last_distance

## search all target groups for the nearest entity
func _find_nearest() -> CDEntity:
	for group in target_groups:
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

## Reset cached direction/distance and the throttle timer on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_update_timer = 0.0
	_last_direction = Vector2.ZERO
	_last_distance = 0.0
