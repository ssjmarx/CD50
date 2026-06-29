## ai_orbit_brain.gd
## Produces: move direction and distance toward a point orbiting a leader at a fixed radius (written to blackboard), with throttled updates and targeting noise.
## Consumes: leader via target_entity_path or target_groups (group_registry); move_key/distance_key blackboard keys.
class_name AIOrbitBrain extends CDEntityComponent

## distance from the leader to orbit at
@export var orbit_radius: float = 50.0

## angular speed in radians per second
@export var orbit_speed: float = 2.0

## seconds between target recalculation (0 = every frame)
@export var update_interval: float = 0.0

## random offset added to leader position for imprecision
@export var targeting_noise: float = 0.0

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

@export_group("Target")
## direct NodePath to leader (optional — falls back to group search)
@export var target_entity_path: NodePath = ""
## groups to search if no direct path is set
@export var target_groups: Array[StringName] = [&"leader"]

## cached reference to the leader entity
var _leader: CDEntity

## accumulated time for orbit angle calculation
var _elapsed: float = 0.0

## timer for throttled updates
var _update_timer: float = 0.0

## cached orbit target for throttled frames
var _last_target_pos: Vector2 = Vector2.ZERO

## Set the intent category before the base _ready lifecycle hooks.
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## ensure move_to signals exist and try to resolve leader from NodePath
func _on_initialize() -> void:
	if target_entity_path:
		var node := get_node_or_null(target_entity_path)
		if node is CDEntity:
			_leader = node

## compute and emit orbit position each frame
func _physics_process(delta: float) -> void:
	_elapsed += delta
	
	if _leader and not is_instance_valid(_leader):
		_leader = null

	if not _leader:
		_acquire_leader()

	if not _leader:
		return

	## compute orbit target: leader position + circular offset
	var leader_pos := _apply_noise(_leader.global_position)
	var angle := _elapsed * orbit_speed
	var offset := Vector2(cos(angle), sin(angle)) * orbit_radius
	var orbit_target := leader_pos + offset

	## if throttled, use cached target until interval expires
	if update_interval > 0.0:
		_update_timer += delta
		if _update_timer < update_interval:
			var to_cached := _last_target_pos - entity.global_position
			entity.blackboard[move_key] = to_cached.normalized()
			entity.blackboard[distance_key] = to_cached.length()
			return
		_update_timer = 0.0

	_last_target_pos = orbit_target
	var to_target := orbit_target - entity.global_position
	entity.blackboard[move_key] = to_target.normalized()
	entity.blackboard[distance_key] = to_target.length()

## search target groups for the nearest leader candidate
func _acquire_leader() -> void:
	for group in target_groups:
		var candidate := game.group_registry.get_nearest(group, entity.global_position)
		if candidate:
			_leader = candidate
			return

## add random offset to leader position if noise is configured
func _apply_noise(pos: Vector2) -> Vector2:
	if targeting_noise <= 0.0:
		return pos
	return pos + Vector2(
		randf_range(-targeting_noise, targeting_noise),
		randf_range(-targeting_noise, targeting_noise)
	)

## Clear the leader reference and reset orbit/throttle state on deactivation.
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_leader = null
	_elapsed = 0.0
	_update_timer = 0.0
	_last_target_pos = Vector2.ZERO
