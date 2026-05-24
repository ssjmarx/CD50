# Modifier manager. Applies active modifier effects to game instances.
# Toggles are configured on the parent ArcadeOrchestrator via export group.
# Setup-time modifiers run once per game load. Runtime modifiers use node_added.

extends Node

# Reference to the ArcadeOrchestrator (set by AO on creation)
var _ao: Node = null
var _is_listening: bool = false

const OVERCLOCK_MULT := 1.25
const SHOTGUN_SPREAD := PI / 12.0  # 15 degrees
const SHOTGUN_OFFSET := 6.0       # pixels perpendicular offset

# --- Public API ---

func set_orchestrator(ao: Node) -> void:
	_ao = ao

# Apply setup-time modifiers (call after add_child, before game start)
func apply_setup_modifiers(game_instance: Node) -> void:
	if _ao.shotgun_mode:
		_walk_and_shotgun_ball_spawners(game_instance)
		_shotgun_pong_thresholds(game_instance)
	if _ao.overclocked_cpu:
		_walk_and_overclock(game_instance)
	if _ao.feature_creep:
		_walk_and_creep_spawners(game_instance, game_instance.scene_file_path)
		_walk_and_feature_creep_splits(game_instance)
		_creep_bug_drop_bottom_spawner(game_instance)
	if _ao.scope_creep:
		_walk_and_scope_creep(game_instance)

# Start listening for dynamically added nodes
func start_listening() -> void:
	if _is_listening:
		return
	if _ao.shotgun_mode or _ao.overclocked_cpu or _ao.scope_creep or _ao.feature_creep:
		get_tree().node_added.connect(_on_node_added)
		_is_listening = true

# Stop listening for dynamically added nodes
func stop_listening() -> void:
	if _is_listening:
		get_tree().node_added.disconnect(_on_node_added)
		_is_listening = false

# Crunch Time helpers
func get_score_multiplier() -> float:
	return 3.0 if _ao.crunch_time else 1.0

func is_crunch_time() -> bool:
	return _ao.crunch_time

# Overclocked CPU helper: multiplier grows faster per game
func get_game_count_increment() -> float:
	return 1.5 if _ao.overclocked_cpu else 1.0

# --- Runtime node detection ---

func _on_node_added(node: Node) -> void:
	if not is_instance_valid(node):
		return
	
	# Shotgun Mode: clone bullets
	if _ao.shotgun_mode and _is_bullet(node):
		_apply_shotgun(node)
	
	# Overclocked CPU: speed up legs
	if _ao.overclocked_cpu and _is_leg(node):
		_apply_overclocked_to_leg(node)
	
	# Overclocked CPU: speed up swarm controllers
	if _ao.overclocked_cpu and _is_swarm_controller(node):
		_apply_overclocked_to_swarm(node)
	
	# Scope Creep: double health
	if _ao.scope_creep and _is_health(node):
		_apply_scope_creep_to_health(node)
	
	# Feature Creep: double split_on_death fragment count
	if _ao.feature_creep and _is_split_on_death(node):
		_apply_feature_creep_to_split(node)

# --- Shotgun Mode ---
# Why fire one bullet when you can fire three?

func _is_bullet(node: Node) -> bool:
	if node.has_meta("_shotgun_clone"):
		return false
	if not node is CharacterBody2D:
		return false
	var scr = node.get_script()
	if not scr:
		return false
	return scr.resource_path.find("bullet") != -1

func _apply_shotgun(bullet: CharacterBody2D) -> void:
	var vel := bullet.velocity
	if vel == Vector2.ZERO:
		return
	var parent_node := bullet.get_parent()
	if not parent_node:
		return
	
	var perp := vel.orthogonal().normalized() * SHOTGUN_OFFSET
	for dir: float in [-1.0, 1.0]:
		var clone: CharacterBody2D = bullet.duplicate()
		clone.set_meta("_shotgun_clone", true)
		clone.global_position = bullet.global_position + perp * dir
		clone.velocity = vel.rotated(SHOTGUN_SPREAD * dir)
		parent_node.add_child(clone)

# --- Shotgun Mode: Ball Spawners ---
# Three balls instead of one. Chaos reigns.

func _walk_and_shotgun_ball_spawners(node: Node) -> void:
	var scr = node.get_script()
	if scr:
		var path: String = scr.resource_path
		if path.find("wave_spawner") != -1 and path.find("tetromino") == -1:
			if "spawn_scene" in node and node.spawn_scene:
				var scene_path: String = node.spawn_scene.resource_path
				if scene_path.find("ball") != -1:
					_shotgun_ball_spawner(node)
	for child in node.get_children():
		_walk_and_shotgun_ball_spawners(child)

func _shotgun_ball_spawner(spawner: Node) -> void:
	if spawner.has_meta("_shotgun_balled"):
		return
	spawner.set_meta("_shotgun_balled", true)
	if "spawn_count_equation" in spawner:
		spawner.spawn_count_equation = "3"

# --- Shotgun Mode: Pong Score Thresholds ---
# First to 2 effective goals instead of first to 1 when 3 balls are in play.
# Must account for arcade_bonus inflating score per goal: int(score_amount * (1 + game_count)).
# Looks up actual score_amount per direction from Goal nodes, then sets
# target_score = 2 × int(score_amount × effective_mult) per PointsMonitor.

func _shotgun_pong_thresholds(game_instance: Node) -> void:
	var scene_path: String = game_instance.scene_file_path
	if scene_path.find("paddle_ball") == -1 and scene_path.find("meteor_rally") == -1:
		return
	var effective_mult: float = 1.0 + _ao._game_count
	# Build map: score_type → score_amount from Goal nodes
	var score_amounts: Dictionary = {}
	_collect_goal_amounts(game_instance, score_amounts)
	_walk_and_set_pong_thresholds(game_instance, effective_mult, score_amounts)

func _collect_goal_amounts(node: Node, score_amounts: Dictionary) -> void:
	var scr = node.get_script()
	if scr and scr.resource_path.find("Scripts/Rules/goal.gd") != -1:
		if "score_type" in node and "score_amount" in node:
			score_amounts[node.score_type] = node.score_amount
	for child in node.get_children():
		_collect_goal_amounts(child, score_amounts)

func _walk_and_set_pong_thresholds(node: Node, effective_mult: float, score_amounts: Dictionary) -> void:
	var scr = node.get_script()
	if scr and scr.resource_path.find("points_monitor") != -1:
		if "target_score" in node and "score_type" in node:
			var st = node.score_type
			if score_amounts.has(st):
				var amount: int = score_amounts[st]
				var score_per_goal: int = int(amount * effective_mult)
				node.target_score = 2 * score_per_goal
	for child in node.get_children():
		_walk_and_set_pong_thresholds(child, effective_mult, score_amounts)

# --- Overclocked CPU ---
# Everything moves 25% faster. Including the enemies.

func _is_leg(node: Node) -> bool:
	var scr = node.get_script()
	if not scr:
		return false
	return scr.resource_path.find("Scripts/Legs/") != -1

func _is_swarm_controller(node: Node) -> bool:
	var scr = node.get_script()
	if not scr:
		return false
	return scr.resource_path.find("swarm_controller") != -1

func _apply_overclocked_to_leg(leg: Node) -> void:
	if leg.has_meta("_overclocked"):
		return
	leg.set_meta("_overclocked", true)
	
	if "speed" in leg:
		leg.speed = int(leg.speed * OVERCLOCK_MULT)
	if "acceleration" in leg:
		leg.acceleration = int(leg.acceleration * OVERCLOCK_MULT)
	if "top_speed" in leg:
		leg.top_speed = int(leg.top_speed * OVERCLOCK_MULT)
	if "hop_delay" in leg:
		leg.hop_delay /= OVERCLOCK_MULT
	if "fall_interval" in leg:
		leg.fall_interval /= OVERCLOCK_MULT

func _apply_overclocked_to_swarm(swarm: Node) -> void:
	if swarm.has_meta("_overclocked"):
		return
	swarm.set_meta("_overclocked", true)
	if "base_tick_interval" in swarm:
		swarm.base_tick_interval /= OVERCLOCK_MULT

func _walk_and_overclock(node: Node) -> void:
	if _is_leg(node):
		_apply_overclocked_to_leg(node)
	if _is_swarm_controller(node):
		_apply_overclocked_to_swarm(node)
	# Overclock wave spawners with initial velocity
	_overclock_spawner_velocity(node)
	for child in node.get_children():
		_walk_and_overclock(child)

func _overclock_spawner_velocity(node: Node) -> void:
	var scr = node.get_script()
	if not scr:
		return
	if scr.resource_path.find("wave_spawner") == -1:
		return
	if node.has_meta("_overclocked"):
		return
	if "initial_velocity" in node and node.initial_velocity != Vector2.ZERO:
		node.set_meta("_overclocked", true)
		node.initial_velocity = node.initial_velocity * OVERCLOCK_MULT

# --- Feature Creep ---
# 1.5x the enemies (rounded down). More chaos. More score.

const CREEP_MULT := 1.5

func _walk_and_creep_spawners(node: Node, scene_path: String) -> void:
	var scr = node.get_script()
	if scr:
		var path: String = scr.resource_path
		if path.find("wave_spawner") != -1 and path.find("tetromino") == -1:
			_creep_wave_spawner(node, scene_path)
		if path.find("ring_spawner") != -1:
			_creep_ring_spawner(node)
	for child in node.get_children():
		_walk_and_creep_spawners(child, scene_path)

func _creep_wave_spawner(spawner: Node, scene_path: String) -> void:
	if spawner.has_meta("_feature_creeped"):
		return
	
	# Bug Drop: handled separately by _creep_bug_drop_bottom_spawner — skip entirely
	if scene_path.find("bug_drop") != -1:
		return
	
	spawner.set_meta("_feature_creeped", true)
	
	# Brick Breaker and remix: multiply height (rows) instead of width
	# Block Drop: multiply rows AND adjust position so bottom edge stays pinned
	var _is_brick_variant: bool = (
		scene_path.find("brick_breaker") != -1 or
		scene_path.find("rock_breaker") != -1
	)
	var _is_block_drop: bool = scene_path.find("block_drop") != -1
	
	if "spawn_pattern" in spawner and spawner.spawn_pattern == CommonEnums.SpawnPattern.GRID:
		if (_is_brick_variant or _is_block_drop) and "grid_rows" in spawner:
			var old_rows: int = spawner.grid_rows
			spawner.grid_rows = int(spawner.grid_rows * CREEP_MULT)
			# Block Drop: pin the bottom edge by shifting spawner position upward
			if _is_block_drop and spawner.grid_rows > old_rows:
				var delta_rows: int = spawner.grid_rows - old_rows
				var step: int = spawner.grid_height + (spawner.grid_spacing if "grid_spacing" in spawner else 0)
				spawner.position.y -= delta_rows * step / 2.0
		elif "grid_columns" in spawner:
			spawner.grid_columns = int(spawner.grid_columns * CREEP_MULT)
	else:
		if "spawn_count_equation" in spawner:
			spawner.spawn_count_equation = "int((%s) * 1.5)" % spawner.spawn_count_equation

func _creep_ring_spawner(spawner: Node) -> void:
	if spawner.has_meta("_feature_creeped"):
		return
	spawner.set_meta("_feature_creeped", true)
	if "spawn_count" in spawner:
		spawner.spawn_count = int(spawner.spawn_count * CREEP_MULT)

# Bug Drop: find the bottommost GRID wave_spawner, expand it vertically,
# and shift it down so the top edge stays contiguous with the spawner above.
func _creep_bug_drop_bottom_spawner(game_instance: Node) -> void:
	var scene_path: String = game_instance.scene_file_path
	if scene_path.find("bug_drop") == -1:
		return
	var spawners: Array[Node] = []
	_collect_grid_spawners(game_instance, spawners)
	if spawners.is_empty():
		return
	# Find the bottommost (highest y-position) grid spawner
	var bottom: Node = spawners[0]
	for s in spawners:
		if s.global_position.y > bottom.global_position.y:
			bottom = s
	if bottom.has_meta("_feature_creeped"):
		return
	bottom.set_meta("_feature_creeped", true)
	if "grid_rows" in bottom:
		bottom.grid_rows = 3
		# Shift down by 1 row height to pin the top edge
		var step: float = float(bottom.grid_height + (bottom.grid_spacing if "grid_spacing" in bottom else 0))
		bottom.position.y += step

func _collect_grid_spawners(node: Node, out: Array[Node]) -> void:
	var scr = node.get_script()
	if scr:
		var path: String = scr.resource_path
		if path.find("wave_spawner") != -1 and path.find("tetromino") == -1:
			if "spawn_pattern" in node and node.spawn_pattern == CommonEnums.SpawnPattern.GRID:
				out.append(node)
	for child in node.get_children():
		_collect_grid_spawners(child, out)

# --- Scope Creep ---
# Bigger healthbars for EVERYTHING.

func _is_health(node: Node) -> bool:
	return node.has_signal("zero_health")

func _apply_scope_creep_to_health(health: Node) -> void:
	if health.has_meta("_scope_creeped"):
		return
	# Only boost health on player-controlled entities
	if not _has_player_control(health):
		return
	health.set_meta("_scope_creeped", true)
	if "max_health" in health:
		health.max_health *= 2
	if "current_health" in health:
		health.current_health = health.max_health

func _has_player_control(node: Node) -> bool:
	var body = node.get_parent()
	if not body:
		return false
	for child in body.get_children():
		var scr = child.get_script()
		if scr and scr.resource_path.find("player_control") != -1:
			return true
	return false

func _walk_and_scope_creep(node: Node) -> void:
	if _is_health(node):
		_apply_scope_creep_to_health(node)
	for child in node.get_children():
		_walk_and_scope_creep(child)

# --- Feature Creep: Split on Death ---
# 1.5x the fragments (rounded down). More chaos.

func _is_split_on_death(node: Node) -> bool:
	var scr = node.get_script()
	if not scr:
		return false
	return scr.resource_path.find("split_on_death") != -1

func _apply_feature_creep_to_split(split: Node) -> void:
	if split.has_meta("_feature_creeped"):
		return
	split.set_meta("_feature_creeped", true)
	if "spawn_count" in split:
		split.spawn_count = int(split.spawn_count * CREEP_MULT)

func _walk_and_feature_creep_splits(node: Node) -> void:
	if _is_split_on_death(node):
		_apply_feature_creep_to_split(node)
	for child in node.get_children():
		_walk_and_feature_creep_splits(child)
