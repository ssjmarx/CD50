# Clear shot AI brain for paddle cannons. Fires straight up only when there is
# a valid target directly above — rejects blocked shots (obstacle hit first) and
# shots into thin air (nothing in the ray path). The cannon positions itself via
# cover_ai's predicted intercept logic, so this brain just decides WHEN to fire.

extends UniversalComponent

# Targeting and firing configuration
@export var target_group: String = "invaders"
@export var fire_rate: float = 2.0
@export var vision_range: float = 500.0

# Runtime state
var _timer: float = 0.0

func _ready() -> void:
	# Randomize initial timer so cannons don't all fire at once
	_timer = randf() * fire_rate

func _physics_process(delta: float) -> void:
	if game.current_state != CommonEnums.State.PLAYING:
		return
	
	_timer += delta
	if _timer < fire_rate:
		return
	
	if _has_target_above():
		parent.shoot.emit()
		_timer = 0.0

# Cast a vertical ray upward. Only returns true if the first thing hit is a valid target.
# Rejects: empty air (nothing hit), blocked shots (obstacle hit first), non-targets.
func _has_target_above() -> bool:
	var space_state = parent.get_world_2d().direct_space_state
	var ray_start = parent.global_position
	var ray_end = ray_start + Vector2(0, -vision_range)
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [parent.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	# Nothing above us — thin air, don't shoot
	if result.is_empty():
		return false
	
	var collider = result["collider"]
	
	# First thing hit is a valid target — clear shot!
	if collider.is_in_group(target_group):
		return true
	
	# First thing hit is an obstacle or something else — blocked
	return false