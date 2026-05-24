# Planetary Attack reset handler. When invaders reach the bottom (wave clear):
# 1. Celebration: kill all enemies via Health component (triggers death animations)
# 2. Pause: 3-second break with all spawners/timers disabled
# 3. Reset: spawn fresh cannons + barriers, then directly trigger invasion spawners

extends Node

var _barrier_scene: PackedScene = preload("res://v1/Scenes/Bodies/generic/barrier.tscn")
var _cannon_scene: PackedScene = preload("res://v1/Scenes/Bodies/nonplayer/nonplayer_paddle_cannon.tscn")

var _cannon_configs: Array[Dictionary] = [
	{ "pos": Vector2(240, 680), "x_min": 180.0, "x_max": 300.0 },
	{ "pos": Vector2(80, 680), "x_min": 20.0, "x_max": 140.0 },
	{ "pos": Vector2(560, 680), "x_min": 500.0, "x_max": 620.0 },
	{ "pos": Vector2(400, 680), "x_min": 340.0, "x_max": 460.0 },
]

var _barrier_configs: Array[Dictionary] = [
	{ "pos": Vector2(80, 640), "scale": Vector2(0.667, 0.667) },
	{ "pos": Vector2(240, 640), "scale": Vector2(0.667, 0.667) },
	{ "pos": Vector2(400, 640), "scale": Vector2(0.667, 0.667) },
	{ "pos": Vector2(560, 640), "scale": Vector2(0.667, 0.667) },
]

var _resetting: bool = false

func _ready() -> void:
	var swarm = get_node_or_null("../SwarmController")
	if swarm:
		swarm.swarm_at_bottom.connect(_on_swarm_at_bottom)

func _on_swarm_at_bottom() -> void:
	if _resetting:
		return
	_resetting = true
	
	# Disable monitors during reset
	_set_monitor_active("GroupMonitorInvaders", false)
	_set_monitor_active("GroupMonitor", false)  # enemies monitor
	
	# Pause triangle/modern spawn timers
	_set_timer_active("TriangleTimer", false)
	_set_timer_active("ModernTimer", false)
	
	# Kill all enemies via Health to trigger death animations
	_kill_all_enemies()
	
	# Free all bricks (barrier blocks)
	_free_group("bricks")
	
	# Wait 3 seconds for celebration
	await get_tree().create_timer(3.0).timeout
	
	# Free any remaining enemies (shouldn't be any, but safety net)
	_free_group("enemies")
	_free_group("invaders")
	
	# Spawn fresh defenses
	_spawn_cannons()
	_spawn_barriers()
	
	# Re-enable monitors (reset their tracking state)
	_reenable_monitor("GroupMonitorInvaders")
	_reenable_monitor("GroupMonitor")
	
	# Re-enable spawn timers
	_set_timer_active("TriangleTimer", true)
	_set_timer_active("ModernTimer", true)
	
	# Directly trigger invasion spawners via WaveDirector4
	var director4 = get_node_or_null("../WaveDirector4")
	if director4:
		var wave = director4.current_wave
		director4.current_wave += 1
		get_parent().spawning_wave.emit(director4, wave)
	
	# Explicitly reset SwarmController so _bottom_triggered is cleared
	# (auto-detection is unreliable during async reset)
	var swarm = get_node_or_null("../SwarmController")
	if swarm:
		swarm._prev_living = 0  # Force new-wave detection
		swarm.reset_wave()
	
	_resetting = false

func _kill_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var health = _find_health(enemy)
			if health and not health._is_dead:
				health.reduce_health(999)
			else:
				enemy.queue_free()
	for invader in get_tree().get_nodes_in_group("invaders"):
		if is_instance_valid(invader):
			var health = _find_health(invader)
			if health and not health._is_dead:
				health.reduce_health(999)
			else:
				invader.queue_free()

func _free_group(group_name: String) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()

func _find_health(node: Node) -> Node:
	for child in node.get_children():
		if child.name == "Health":
			return child
	return null

func _set_monitor_active(node_name: String, active: bool) -> void:
	var monitor = get_node_or_null("../" + node_name)
	if monitor:
		monitor.set_physics_process(active)

func _reenable_monitor(node_name: String) -> void:
	var monitor = get_node_or_null("../" + node_name)
	if monitor:
		monitor._previous_count = -1
		monitor.set_physics_process(true)

func _set_timer_active(node_name: String, active: bool) -> void:
	var timer_node = get_node_or_null("../" + node_name)
	if timer_node:
		if active:
			timer_node.start_timer()
		else:
			timer_node.stop_timer()

func _spawn_cannons() -> void:
	for config in _cannon_configs:
		var cannon = _cannon_scene.instantiate()
		cannon.position = config["pos"]
		cannon.x_min = config["x_min"]
		cannon.x_max = config["x_max"]
		get_parent().add_child(cannon)

func _spawn_barriers() -> void:
	for config in _barrier_configs:
		var barrier = _barrier_scene.instantiate()
		barrier.position = config["pos"]
		barrier.scale = config["scale"]
		get_parent().add_child(barrier)
