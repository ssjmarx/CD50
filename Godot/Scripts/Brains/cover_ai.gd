# Cover AI brain for paddle cannons. Seeks cover under bunkers when bullets
# are incoming, otherwise tracks the closest invader horizontally.

extends UniversalComponent

# Targeting configuration
@export var target_group: String = "invaders"
@export var threat_group: String = "players_bullets"
@export var cover_group: String = "bricks"
@export var danger_distance: float = 100.0
@export var tracking_speed: float = 100.0

# Runtime state
var _taking_cover: bool = false

func _physics_process(delta: float) -> void:
	if game.current_state != CommonEnums.State.PLAYING:
		return
	
	var move_dir: Vector2 = Vector2.ZERO
	
	if _is_under_threat():
		_taking_cover = true
		var cover_pos = _find_nearest_cover()
		if cover_pos != null:
			move_dir = _move_toward_x(cover_pos.x, delta)
	else:
		_taking_cover = false
		var target_pos = _find_closest_target()
		if target_pos != null:
			move_dir = _move_toward_x(target_pos.x, delta)
	
	parent.move.emit(move_dir)

# Check if any bullet in the threat group is within danger distance above us
func _is_under_threat() -> bool:
	for bullet in get_group_nodes(threat_group):
		if not is_instance_valid(bullet):
			continue
		var dist = parent.global_position.distance_to(bullet.global_position)
		if dist < danger_distance:
			# Check if bullet is above or at our level (coming toward us)
			if bullet.global_position.y <= parent.global_position.y:
				return true
	return false

# Find the nearest brick/bunker x-position for cover
func _find_nearest_cover() -> Variant:
	var closest_pos: Vector2 = Vector2.ZERO
	var closest_dist: float = INF
	
	for brick in get_group_nodes(cover_group):
		if not is_instance_valid(brick):
			continue
		var dist = abs(brick.global_position.x - parent.global_position.x)
		if dist < closest_dist:
			closest_dist = dist
			closest_pos = brick.global_position
	
	if closest_dist < INF:
		return closest_pos
	return null

# Find the closest target in the target group
func _find_closest_target() -> Variant:
	var closest_pos: Vector2 = Vector2.ZERO
	var closest_dist: float = INF
	
	for target in get_group_nodes(target_group):
		if not is_instance_valid(target):
			continue
		var dist = parent.global_position.distance_squared_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_pos = target.global_position
	
	if closest_dist < INF:
		return closest_pos
	return null

# Move horizontally toward a target x position
func _move_toward_x(target_x: float, delta: float) -> Vector2:
	var diff = target_x - parent.global_position.x
	if abs(diff) < 2.0:
		return Vector2.ZERO
	return Vector2(sign(diff), 0.0)
