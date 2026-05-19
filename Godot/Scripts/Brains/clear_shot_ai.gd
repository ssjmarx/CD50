# Clear shot AI brain for paddle cannons. Only fires when there is a clear
# line of sight to the closest target — no intervening obstacles (bricks/bunkers).

extends UniversalComponent

# Targeting and firing configuration
@export var target_group: String = "invaders"
@export var obstacle_group: String = "bricks"
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
	
	var target = _find_clear_shot_target()
	if target != null:
		parent.aim.emit(Vector2.UP)
		parent.shoot.emit()
		_timer = 0.0

# Find the closest target that has a clear line of sight
func _find_clear_shot_target() -> Node2D:
	var target_nodes := get_group_nodes(target_group)
	var closest_node: Node2D = null
	var closest_dist: float = INF
	
	# Find closest target
	for node in target_nodes:
		if not is_instance_valid(node):
			continue
		if not node is Node2D:
			continue
		var dist = parent.global_position.distance_squared_to(node.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_node = node
	
	if closest_node == null:
		return null
	
	# Check range
	if vision_range > 0 and closest_dist > vision_range * vision_range:
		return null
	
	# Raycast for clear line of sight
	if _has_clear_shot(closest_node):
		return closest_node
	
	return null

# Check if there is a clear line of sight to the target using raycast
func _has_clear_shot(target: Node2D) -> bool:
	var space_state = parent.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		parent.global_position,
		target.global_position
	)
	query.exclude = [parent.get_rid()]
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true  # Nothing in the way
	
	# Check if what we hit is the target itself (or a child of it)
	var collider = result["collider"]
	if collider == target:
		return true
	
	# Check if the collider is in the obstacle group — blocked
	if collider.is_in_group(obstacle_group):
		return false
	
	# If it's something else (another invader, etc.), still blocked
	return false