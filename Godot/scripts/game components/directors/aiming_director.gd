## AimingDirector
## Per-entity nearest-target aiming across groups
## Each shooter independently finds its closest threat — a large formation can aim in multiple directions Writes aim_direction to entity blackboard (distinct from move_direction)

@tool
class_name AimingDirector extends CDGameComponent

## --- exports ---

## groups containing entities that should aim
@export var shooter_groups: Array[StringName] = [&"enemies"]

## groups to search for aim targets
@export var target_groups: Array[StringName] = [&"players"]

@export_group("Timing")
## seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

@export_group("Precision")
## random offset added to target position for imprecision
@export var targeting_noise: float = 0.0

@export_group("Blackboard Keys")
## key for writing aim direction to entity blackboard (Vector2, normalized)
@export var aim_key: StringName = &"aim_direction"

## --- state ---

## timer for throttled target recalculation
var _update_timer: float = 0.0
## cached direction per entity (for throttled frames)
var _cached_directions: Dictionary = {}

## --- lifecycle ---

## ready
func _ready() -> void:
	super._ready()
	component_category = CDEnums.ComponentCategory.RULES

## --- processing ---

## physics process
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	var shooters := _gather_shooters()
	if shooters.is_empty():
		return
	
	## throttled mode: write cached directions until interval expires
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			_write_cached(shooters)
			return
		_update_timer = 0.0
	
	## full recalculation: find nearest target for each shooter
	_cached_directions.clear()
	for shooter in shooters:
		var direction := _calculate_aim(shooter)
		if direction != Vector2.ZERO:
			_cached_directions[shooter] = direction
			shooter.blackboard[aim_key] = direction

## --- aiming ---

## find the nearest target across all target groups for a given shooter
func _calculate_aim(shooter: CDEntity) -> Vector2:
	var nearest_dist_sq := INF
	var nearest_pos := Vector2.ZERO
	
	for group in target_groups:
		var target := game.group_registry.get_nearest(group, shooter.global_position)
		if target:
			var dist_sq := shooter.global_position.distance_squared_to(target.global_position)
			if dist_sq < nearest_dist_sq:
				nearest_dist_sq = dist_sq
				nearest_pos = target.global_position
	
	if nearest_dist_sq < INF:
		return shooter.global_position.direction_to(_apply_noise(nearest_pos))
	
	return Vector2.ZERO

## add random offset to target position if noise is configured
func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

## write cached aim directions to entity blackboards
func _write_cached(shooters: Array[CDEntity]) -> void:
	for shooter in shooters:
		if _cached_directions.has(shooter):
			shooter.blackboard[aim_key] = _cached_directions[shooter]

## gather entities from all shooter groups (deduplicated, valid, active)
func _gather_shooters() -> Array[CDEntity]:
	var seen: Dictionary = {}
	var result: Array[CDEntity] = []
	
	for group_name in shooter_groups:
		for entity in game.group_registry.get_group(group_name):
			if not seen.has(entity):
				seen[entity] = true
				if is_instance_valid(entity) and entity.state == CDEnums.EntityState.ACTIVE:
					result.append(entity)
	
	return result

## --- reset ---

## reset
func reset() -> void:
	_update_timer = 0.0
	_cached_directions.clear()