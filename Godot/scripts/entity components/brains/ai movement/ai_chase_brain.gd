# AIChaseBrain
# Emits move direction toward the nearest entity in target groups
# Stops moving when within stop_distance of the target

class_name AIChaseBrain extends CDEntityComponent

# groups to search for chase targets
@export var target_groups: Array[StringName] = [&"enemies"]

# stop emitting move when this close to target
@export var stop_distance: float = 10.0

# seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

# random offset added to target position for imprecision
@export var targeting_noise: float = 0.0

@export var move_key: StringName = &"move_direction"

# timer for throttled updates
var _update_timer: float = 0.0

# cached direction for throttled frames
var _last_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

# emit move direction each frame, recalculate target on interval
func _physics_process(delta: float) -> void:
	# if throttled, write cached direction to the blackboard
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			entity.blackboard[move_key] = _last_direction
			return
		_update_timer = 0.0

	# find nearest target across all groups
	var target := _find_nearest()
	if target == null:
		_last_direction = Vector2.ZERO
		entity.blackboard[move_key] = _last_direction
		return

	var target_pos := _apply_noise(target.global_position)
	var distance := entity.global_position.distance_to(target_pos)

	# stop if within range
	if distance <= stop_distance:
		_last_direction = Vector2.ZERO
		entity.blackboard[move_key] = _last_direction
		return

	# emit direction toward target
	_last_direction = entity.global_position.direction_to(target_pos)
	entity.blackboard[move_key] = _last_direction

# search all target groups for the nearest entity
func _find_nearest() -> CDEntity:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			return candidate
	return null

# add random offset to target position if noise is configured
func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_update_timer = 0.0
	_last_direction = Vector2.ZERO
