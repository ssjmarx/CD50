# Arcade Orchestrator. State machine that manages the arcade run: BOOT → PLAYING → RESULT → GAME_OVER → RESTART.
# Loads games from ArcadeGameEntry resources, tracks lives/score, detects game end, applies property overrides.
# Emits Interface-compatible signals so a child Interface component can display score, lives, and multiplier.

extends Node2D

enum OrchestratorState { BOOT, PLAYING, RESULT, GAME_OVER }
enum PlaylistMode { IN_ORDER, SHUFFLE }

@export var playlist: Array[ArcadeGameEntry] = []
@export var starting_lives: int = 3
@export var playlist_mode: PlaylistMode = PlaylistMode.IN_ORDER

# Signals for Interface component
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: float)
signal lives_changed(new_lives: int)
signal state_changed(new_state: CommonEnums.State)

var _state: OrchestratorState = OrchestratorState.BOOT
var _lives: int
var _running_score: int = 0
var _current_index: int = 0
var _current_game_instance: Node2D = null
var _last_game_won: bool = false
var _result_timer: float = 0.0
var _shuffle_bag: Array[int] = []
var _current_interface: Control = null

# Per-game tracking
var _game_count: int = 0          # games completed this run (drives per-game bonus)
var _game_multiplier: float = 1.0  # current game's own multiplier (resets each game)
var _game_start_time: float = 0.0 # when current game started (seconds since epoch)

@onready var _game_container: Node2D = $GameContainer
@onready var _boot_screen: Control = $BootScreen
@onready var _game_over_screen: Control = $GameOverScreen

func _ready() -> void:
	_lives = starting_lives
	_show_boot_screen()

func _input(event: InputEvent) -> void:
	match _state:
		OrchestratorState.BOOT:
			if event.is_action_pressed("start") or event.is_action_pressed("coin"):
				_start_next_game()
				get_viewport().set_input_as_handled()
		OrchestratorState.GAME_OVER:
			if event.is_action_pressed("start") or event.is_action_pressed("coin"):
				_restart_run()
				get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _state == OrchestratorState.RESULT:
		_result_timer -= delta
		if _result_timer <= 0.0:
			if _lives > 0:
				_start_next_game()
			else:
				_show_game_over()

# --- State transitions ---

func _show_boot_screen() -> void:
	_state = OrchestratorState.BOOT
	state_changed.emit(CommonEnums.State.ATTRACT)
	_boot_screen.visible = true
	_game_over_screen.visible = false

func _start_next_game() -> void:
	if playlist.is_empty():
		push_error("ArcadeOrchestrator: playlist is empty")
		return
		
	var entry: ArcadeGameEntry
	
	if playlist_mode == PlaylistMode.SHUFFLE:
		if _shuffle_bag.is_empty():
			_refill_shuffle_bag()
		entry = playlist[_shuffle_bag.pop_front()]
	else:
		# Existing in-order logic
		if _current_index >= playlist.size():
			_current_index = 0
		entry = playlist[_current_index]
	
	_state = OrchestratorState.PLAYING
	_boot_screen.visible = false
	_game_over_screen.visible = false
	
	_load_and_start_game(entry)
	
	# Emit PLAYING AFTER game is loaded so Interface can discover timers in the tree
	state_changed.emit(CommonEnums.State.PLAYING)

func _load_and_start_game(entry: ArcadeGameEntry) -> void:
	# Free previous game if any
	if _current_game_instance:
		_current_game_instance.queue_free()
		_current_game_instance = null
	
	# Instance the game scene
	_current_game_instance = entry.game_scene.instantiate()
	
	# Get the UGS and configure for arcade mode BEFORE adding to tree
	var ugs: UniversalGameScript = _current_game_instance as UniversalGameScript
	if not ugs:
		ugs = _find_ugs(_current_game_instance)
	
	if ugs:
		ugs.mode = UniversalGameScript.Mode.ARCADE
		
		# Connect to victory/defeat BEFORE UGS _ready connects them to p1_win/p1_lose
		ugs.victory.connect(_on_game_victory)
		ugs.defeat.connect(_on_game_defeat)
		ugs.on_game_over.connect(_on_game_over_signal)
		ugs.on_points_changed.connect(_on_game_points_changed)
		ugs.on_multiplier_changed.connect(_on_game_multiplier_changed)
		ugs.lives_changed.connect(_on_game_lives_changed)
		
		# Apply property overrides BEFORE adding to tree so @onready captures them
		_apply_overrides(_current_game_instance, entry.overrides)
		
		# Add to tree — _ready() runs here with overrides already applied
		_game_container.add_child(_current_game_instance)
		
		# Take over the child game's Interface for arcade display
		_takeover_interface(ugs)
		
		# Reset per-game state
		_game_multiplier = 1.0
		_game_start_time = Time.get_ticks_msec() / 1000.0
		
		# Show combined multiplier (game's + per-game bonus)
		on_multiplier_changed.emit(_game_multiplier + _game_count)
		
		# Notify UGS of arcade bonus so scoring is affected
		ugs.set_arcade_bonus(float(_game_count))
		
		# Start the game
		ugs.start_game()
	else:
		push_error("ArcadeOrchestrator: could not find UniversalGameScript in game scene")
		_current_game_instance.queue_free()
		_current_game_instance = null

func _on_game_victory() -> void:
	_last_game_won = true

func _on_game_defeat() -> void:
	_last_game_won = false

func _on_game_over_signal(final_score: int) -> void:
	# Increment game count only on victory (drives per-game multiplier bonus)
	if _last_game_won:
		_game_count += 1
	
	# Update UGS arcade bonus for scoring during this game
	var ugs = _get_current_ugs()
	if ugs:
		ugs.set_arcade_bonus(float(_game_count))
	
	# Time bonus only awarded on victory, scaled by current game count
	var time_bonus: int = 0
	if _last_game_won:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game_start_time
		var base_bonus = _calc_time_bonus(elapsed)
		time_bonus = base_bonus * _game_count
		#print("[AO] time_bonus: base=%d × game_count=%d = %d (elapsed %.1fs)" % [
		#	base_bonus, _game_count, time_bonus, elapsed])
	
	# Apply time bonus and game score to running total
	_running_score += final_score + time_bonus
	#print("[AO] game_over: final_score=%d + time_bonus=%d → running_total=%d (won=%s, game_count=%d)" % [
	#	final_score, time_bonus, _running_score, _last_game_won, _game_count])
	on_points_changed.emit(_running_score)
	
	if not _last_game_won:
		_lives -= 1
		lives_changed.emit(_lives)
	
	if playlist_mode == PlaylistMode.IN_ORDER:
		_current_index += 1
	
	# Transition to RESULT state
	_state = OrchestratorState.RESULT
	_result_timer = 0.5

func _on_game_points_changed(new_score: int) -> void:
	# Game emits its own score changes — update running total live
	# We recalculate: running_score = accumulated + current game score
	on_points_changed.emit(_running_score + new_score)

func _on_game_multiplier_changed(new_multiplier: float) -> void:
	_game_multiplier = new_multiplier
	# Combine game's multiplier with per-game bonus
	on_multiplier_changed.emit(_game_multiplier + _game_count)

func _on_game_lives_changed(new_lives: int) -> void:
	lives_changed.emit(_lives)

func _show_game_over() -> void:
	_state = OrchestratorState.GAME_OVER
	state_changed.emit(CommonEnums.State.GAME_OVER)
	if _current_game_instance:
		_current_game_instance.queue_free()
		_current_game_instance = null
	_current_interface = null
	_game_over_screen.visible = true
	# Update final score label
	var final_score_label: Label = _game_over_screen.get_node_or_null("FinalScoreLabel")
	if final_score_label:
		final_score_label.text = "FINAL SCORE: %d" % _running_score

func _restart_run() -> void:
	_current_interface = null
	_lives = starting_lives
	_running_score = 0
	_current_index = 0
	_shuffle_bag.clear()   # forces reshuffle on next game
	_game_count = 0
	_game_multiplier = 1.0
	lives_changed.emit(_lives)
	on_points_changed.emit(0)
	on_multiplier_changed.emit(1.0)
	var ugs = _get_current_ugs()
	if ugs:
		ugs.set_arcade_bonus(0.0)
	_show_boot_screen()

# --- Helpers ---

func _get_current_ugs() -> UniversalGameScript:
	if not _current_game_instance:
		return null
	var ugs = _current_game_instance as UniversalGameScript
	if not ugs:
		ugs = _find_ugs(_current_game_instance)
	return ugs

func _find_ugs(node: Node) -> UniversalGameScript:
	if node is UniversalGameScript:
		return node
	for child in node.get_children():
		var result = _find_ugs(child)
		if result:
			return result
	return null

func _calc_time_bonus(elapsed: float) -> int:
	# 1000 points at ≤20s, linearly to 0 at ≥60s
	if elapsed <= 20.0:
		return 1000
	elif elapsed >= 60.0:
		return 0
	else:
		return int((1.0 - (elapsed - 20.0) / 40.0) * 1000.0)

func _apply_overrides(game_instance: Node, overrides: Array[PropertyOverride]) -> void:
	for prop_override: PropertyOverride in overrides:
		if prop_override.node_path.is_empty():
			continue
		var target_node = game_instance.get_node_or_null(prop_override.node_path)
		if target_node:
			target_node.set(prop_override.property_name, prop_override.value)
		else:
			push_warning("ArcadeOrchestrator: override node '%s' not found in game scene" % prop_override.node_path)

func _refill_shuffle_bag() -> void:
	_shuffle_bag.clear()
	_shuffle_bag.resize(playlist.size())
	for i in playlist.size():
		_shuffle_bag[i] = i
	_shuffle_bag.shuffle()

# --- Interface Takeover ---

func _takeover_interface(ugs: UniversalGameScript) -> void:
	var iface = ugs.get_node_or_null("Interface")
	if not iface:
		push_warning("ArcadeOrchestrator: no Interface found in game scene")
		return
	
	_current_interface = iface
	
	# Force arcade display mode
	iface.display_mode = CommonEnums.DisplayMode.POINTS_MULTIPLIER
	iface.display_lives = true
	
	# Disconnect from UGS (AO overrides these 4 signals)
	if ugs.on_points_changed.is_connected(iface.set_points):
		ugs.on_points_changed.disconnect(iface.set_points)
	if ugs.on_multiplier_changed.is_connected(iface.set_multiplier):
		ugs.on_multiplier_changed.disconnect(iface.set_multiplier)
	if ugs.lives_changed.is_connected(iface.set_lives):
		ugs.lives_changed.disconnect(iface.set_lives)
	if ugs.state_changed.is_connected(iface._on_state_changed):
		ugs.state_changed.disconnect(iface._on_state_changed)
	
	# Connect to AO signals instead
	on_points_changed.connect(iface.set_points)
	on_multiplier_changed.connect(iface.set_multiplier)
	lives_changed.connect(iface.set_lives)
	state_changed.connect(iface._on_state_changed)
	
	# Set initial values (disable animation for instant snap)
	iface.animate_score = false
	iface.set_points(_running_score)
	iface.set_multiplier(1.0 + _game_count)
	iface.set_lives(_lives)
	iface.animate_score = true
