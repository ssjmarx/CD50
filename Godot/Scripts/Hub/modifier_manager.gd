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
	if _ao.overclocked_cpu:
		_walk_and_overclock(game_instance)
	if _ao.feature_creep:
		_walk_and_double_spawners(game_instance)
		_walk_and_feature_creep_splits(game_instance)
		_fix_bug_drop_line_clear(game_instance)
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
	for child in node.get_children():
		_walk_and_overclock(child)

# --- Feature Creep ---
# Double the enemies. Double the chaos. Double the score.

func _walk_and_double_spawners(node: Node) -> void:
	var scr = node.get_script()
	if scr:
		var path: String = scr.resource_path
		if path.find("wave_spawner") != -1 and path.find("tetromino") == -1:
			_double_wave_spawner(node)
		if path.find("ring_spawner") != -1:
			_double_ring_spawner(node)
	for child in node.get_children():
		_walk_and_double_spawners(child)

func _double_wave_spawner(spawner: Node) -> void:
	if spawner.has_meta("_feature_creeped"):
		return
	spawner.set_meta("_feature_creeped", true)
	
	if "spawn_pattern" in spawner and spawner.spawn_pattern == CommonEnums.SpawnPattern.GRID:
		if "grid_columns" in spawner:
			spawner.grid_columns *= 2
	else:
		if "spawn_count_equation" in spawner:
			spawner.spawn_count_equation = "(%s) * 2" % spawner.spawn_count_equation

func _double_ring_spawner(spawner: Node) -> void:
	if spawner.has_meta("_feature_creeped"):
		return
	spawner.set_meta("_feature_creeped", true)
	if "spawn_count" in spawner:
		spawner.spawn_count *= 2

# Bug Drop fix: when Feature Creep doubles the invader grid, the line clear
# monitor's detection columns must also double so tetrominos still "fill" rows.
func _fix_bug_drop_line_clear(game_instance: Node) -> void:
	var scene_path: String = game_instance.scene_file_path
	if scene_path.find("bug_drop") == -1:
		return
	_walk_and_double_line_clear_columns(game_instance)

func _walk_and_double_line_clear_columns(node: Node) -> void:
	var scr = node.get_script()
	if scr and scr.resource_path.find("line_clear_monitor") != -1:
		if "columns" in node and "playfield_origin" in node and "cell_size" in node:
			var original_cols: int = node.columns
			node.columns *= 2
			# Shift origin left by half the added width to center the expanded detection area
			node.playfield_origin.x -= original_cols * node.cell_size.x / 2.0
	for child in node.get_children():
		_walk_and_double_line_clear_columns(child)

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
# Double the fragments. Double the chaos.

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
		split.spawn_count *= 2

func _walk_and_feature_creep_splits(node: Node) -> void:
	if _is_split_on_death(node):
		_apply_feature_creep_to_split(node)
	for child in node.get_children():
		_walk_and_feature_creep_splits(child)
