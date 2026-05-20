# Cover AI brain for paddle cannons. Detects incoming bullets in a vertical
# column matching the cannon's hitbox width, then dodges in the smartest direction.
# When not under threat, moves to the predicted intercept position so the cannon
# is directly below where the target will be when a straight-up shot arrives.

extends UniversalComponent

# Targeting configuration
@export var target_group: String = "invaders"
@export var threat_group: String = "players_bullets"
@export var cover_group: String = "bricks"
@export var vision_height: float = 500.0
@export var bullet_speed: float = 400.0
@export var threat_margin: float = 16.0

# Runtime state
var _taking_cover: bool = false
var _scan_width: float = 20.0

# Target velocity tracking (frame-to-frame position delta)
var _target_ref: WeakRef = null
var _target_last_pos: Vector2 = Vector2.ZERO
var _observed_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Read the cannon's collision width for the threat column
	var col = parent.get_node_or_null("CollisionShape2D")
	if col and col.shape:
		_scan_width = col.shape.size.x + threat_margin
	else:
		_scan_width = 20.0 + threat_margin

func _physics_process(delta: float) -> void:
	if game.current_state != CommonEnums.State.PLAYING:
		return
	
	# Track target velocity every frame
	_update_target_tracking(delta)
	
	var move_dir: Vector2 = Vector2.ZERO
	
	var threat = _get_closest_threat()
	if threat != null:
		_taking_cover = true
		move_dir = _pick_dodge_direction(threat)
	else:
		_taking_cover = false
		var intercept_x = _get_predicted_intercept_x()
		if intercept_x != null:
			move_dir = _move_toward_x(intercept_x)
	
	parent.move.emit(move_dir)

# ── Target velocity tracking ──────────────────────────────────────

func _update_target_tracking(delta: float) -> void:
	var target = _find_closest_target_node()
	
	if target == null:
		_target_ref = null
		_observed_velocity = Vector2.ZERO
		return
	
	var prev_target = _target_ref.get_ref() if _target_ref else null
	if target != prev_target:
		_target_ref = weakref(target)
		_target_last_pos = target.global_position
		_observed_velocity = Vector2.ZERO
		return
	
	# Same target — compute observed velocity from position delta
	if delta > 0.0:
		_observed_velocity = (target.global_position - _target_last_pos) / delta
	_target_last_pos = target.global_position

# Find the closest target node (for tracking purposes)
func _find_closest_target_node() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	
	for target in get_group_nodes(target_group):
		if not is_instance_valid(target):
			continue
		if not target is Node2D:
			continue
		var dist = parent.global_position.distance_squared_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = target
	
	return closest

# Predict where the target will be when a straight-up bullet reaches it.
# Returns the predicted x position, or null if no target.
func _get_predicted_intercept_x() -> Variant:
	var target = _target_ref.get_ref() if _target_ref else null
	if target == null or not is_instance_valid(target):
		return null
	
	var target_pos = target.global_position
	var my_pos = parent.global_position
	
	# Time for a bullet going straight up to reach the target's y level
	var vertical_distance = my_pos.y - target_pos.y
	if vertical_distance <= 0.0:
		return null
	
	var time_to_target = vertical_distance / bullet_speed if bullet_speed > 0.0 else 0.0
	
	# Predict where the target will be at that time
	var predicted_x = target_pos.x + _observed_velocity.x * time_to_target
	
	# Clamp to movement boundaries
	predicted_x = clampf(predicted_x, parent.x_min, parent.x_max)
	
	return predicted_x

# ── Threat detection ──────────────────────────────────────────────

# Find the nearest bullet in the threat group that's in our hitbox column and above us
func _get_closest_threat() -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = INF
	var half_w = _scan_width / 2.0
	var my_x = parent.global_position.x
	var my_y = parent.global_position.y
	
	for bullet in get_group_nodes(threat_group):
		if not is_instance_valid(bullet):
			continue
		# Must be above us (lower y) and within vision height
		var bpos = bullet.global_position
		if bpos.y > my_y:
			continue
		var height_diff = my_y - bpos.y
		if height_diff > vision_height:
			continue
		# Must be within our hitbox column (x alignment)
		if abs(bpos.x - my_x) > half_w:
			continue
		if height_diff < closest_dist:
			closest_dist = height_diff
			closest = bullet
	
	return closest

# Pick the smartest dodge direction based on bullet position and boundary space
func _pick_dodge_direction(threat: Node2D) -> Vector2:
	var my_x = parent.global_position.x
	var bullet_x = threat.global_position.x
	var diff = my_x - bullet_x
	
	# If bullet is centered on us, pick the side with more space
	if abs(diff) < 2.0:
		var space_left = my_x - parent.x_min
		var space_right = parent.x_max - my_x
		return Vector2(-1.0 if space_left > space_right else 1.0, 0.0)
	
	# Dodge away from the bullet offset (bullet slightly left → dodge right)
	var away = sign(diff)
	
	# Check if we have space to dodge that direction
	var space_in_away_dir = (parent.x_max - my_x) if away > 0 else (my_x - parent.x_min)
	if space_in_away_dir < _scan_width:
		# Not enough space — dodge the other way instead
		away = -away
	
	return Vector2(away, 0.0)

# ── Movement helper ───────────────────────────────────────────────

# Move horizontally toward a target x position
func _move_toward_x(target_x: float) -> Vector2:
	var diff = target_x - parent.global_position.x
	if abs(diff) < 2.0:
		return Vector2.ZERO
	return Vector2(sign(diff), 0.0)
