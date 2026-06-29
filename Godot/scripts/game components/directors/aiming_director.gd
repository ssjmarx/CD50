## AimingDirector
## Produces: per-shooter "aim_direction" blackboard key pointing at its nearest target.
## Consumes: target_groups via game.group_registry; optional angle-limit config.

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

@export_group("Angle Limits")
## Enable angle clamping. If false, 360-degree aiming is allowed.
@export var use_angle_limit: bool = false

## Minimum absolute angle limit (in degrees, 0 = East).
@export var min_angle_offset: float = -180.0

## Maximum absolute angle limit (in degrees, 0 = East).
@export var max_angle_offset: float = 180.0

## --- state ---

## timer for throttled target recalculation
var _update_timer: float = 0.0
## cached direction per entity (for throttled frames)
var _cached_directions: Dictionary = {}

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.RULES
	super._ready()

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
		var raw_direction := shooter.global_position.direction_to(_apply_noise(nearest_pos))
		
		if use_angle_limit:
			raw_direction = _clamp_angle_absolute(raw_direction)
		
		return raw_direction
	
	return Vector2.ZERO

## Clamps a direction vector to within [min_angle_offset, max_angle_offset] in absolute world space.
## Godot angles: 0 is East, positive is Clockwise (Down), negative is Counter-Clockwise (Up).
func _clamp_angle_absolute(direction: Vector2) -> Vector2:
	## 1. read the desired heading in degrees (0 = East)
	var angle_deg := rad_to_deg(direction.angle())
	
	## 2. clamp to the configured absolute limits
	var clamped_deg := clampf(angle_deg, min_angle_offset, max_angle_offset)
	
	## 3. rebuild a unit vector from the clamped heading
	return Vector2.from_angle(deg_to_rad(clamped_deg))

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
	return game.group_registry.get_groups_union(shooter_groups, true)

## reset
func reset() -> void:
	_update_timer = 0.0
	_cached_directions.clear()
