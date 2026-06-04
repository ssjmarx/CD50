## AIIdleWanderBrain
## Picks random nearby points and meanders toward them with idle pauses
## Centers wander area on the entity's spawn position

class_name AIIdleWanderBrain extends CDEntityComponent

## max distance from spawn center to pick wander targets
@export var wander_radius: float = 100.0

## seconds to idle between wander moves
@export var idle_time: float = 2.0

## distance to consider a wander target reached
@export var arrival_distance: float = 5.0

## if stuck this long without reaching target, pick a new one
@export var stuck_timeout: float = 3.0

@export_group("Blackboard Keys")
@export var move_key: StringName = &"move_direction"
@export var distance_key: StringName = &"move_distance"

## center of the wander area (set to spawn position)
var _center: Vector2

## current wander target
var _target: Vector2

## countdown timer for idle pauses
var _idle_timer: float = 0.0

## whether currently idling between moves
var _is_idle: bool = false

## timer to detect being stuck
var _stuck_timer: float = 0.0

## ready
func _ready() -> void:
	component_category = CDEnums.ComponentCategory.INTENT
	super._ready()

## pick the first wander target
func _on_initialize() -> void:
	_center = entity._spawn_position
	_pick_new_target()

## emit move_to target while wandering, count idle/stuck timers
func _physics_process(delta: float) -> void:
	## count down idle timer, pick new target when it expires
	if _is_idle:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_is_idle = false
			_pick_new_target()
		return

	var to_target := _target - entity.global_position
	entity.blackboard[move_key] = to_target.normalized()
	entity.blackboard[distance_key] = to_target.length()

	## detect stuck state — pick new target if stuck too long
	_stuck_timer += delta
	if _stuck_timer >= stuck_timeout:
		_stuck_timer = 0.0
		_pick_new_target()
		return

	## check if target reached — begin idle
	if entity.global_position.distance_to(_target) < arrival_distance:
		_is_idle = true
		_idle_timer = idle_time
		_stuck_timer = 0.0

## pick a random point within wander_radius of the center
func _pick_new_target() -> void:
	_stuck_timer = 0.0
	var angle := randf() * TAU
	var distance := randf() * wander_radius
	_target = _center + Vector2(cos(angle), sin(angle)) * distance

## on entity deactivating
func _on_entity_deactivating() -> void:
	super._on_entity_deactivating()
	_is_idle = false
	_idle_timer = 0.0
