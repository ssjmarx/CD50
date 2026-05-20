# Arcade Orchestrator. State machine that manages the arcade run: BOOT → PLAYING → GAME_OVER → RESTART.
# Games are isolated in SubViewports for complete physics/signal separation.
# Win/loss VFX play simultaneously with the slide transition.
# CRT effects are a sibling layer on top, independent of game viewports.

extends Node2D

enum OrchestratorState { BOOT, PLAYING, GAME_OVER, TRANSITIONING }
enum PlaylistMode { IN_ORDER, SHUFFLE, SEMI_RANDOM }

@export var playlist: Array[ArcadeGameEntry] = []
@export var starting_lives: int = 3
@export var playlist_mode: PlaylistMode = PlaylistMode.IN_ORDER
@export var transition_duration: float = 0.4

# --- Modifiers (editor toggles, manual override for now) ---
@export_group("Modifiers")
@export var shotgun_mode: bool = false
@export var overclocked_cpu: bool = false
@export var feature_creep: bool = false
@export var crunch_time: bool = false
@export var scope_creep: bool = false

# --- Music volume control (delegates to MusicPlayer component) ---
@export_group("Music")
@export var music_volume_db: float = -6.0
@export var music_idle_volume_db: float = -20.0
@export var music_fade_in_duration: float = 1.0
@export var music_fade_out_duration: float = 0.5

# Signals for Interface component
signal on_points_changed(new_score: int)
signal on_multiplier_changed(new_multiplier: float)
signal lives_changed(new_lives: int)
signal state_changed(new_state: CommonEnums.State)
signal game_defeat
signal game_victory

const VIEWPORT_HEIGHT: float = 360.0
const GAME_SIZE := Vector2i(640, 360)

var _state: OrchestratorState = OrchestratorState.BOOT
var _lives: int
var _running_score: int = 0
var _current_index: int = 0
var _current_game_instance: Node2D = null
var _active_vpc: SubViewportContainer = null  # Current game's viewport container
var _last_game_won: bool = false
var _shuffle_bag: Array[int] = []
var _current_interface: Control = null
var _transition_tween: Tween = null

# Semi-random playlist state
# Phases: 0=REMAKE×2, 1=LITE_REMIX×2, 2=REMAKE+LITE×4, 3=HEAVY×2, 4=ALL(endless)
var _sr_phase: int = 0
var _sr_games_played_in_phase: int = 0
var _sr_phase_bag: Array[int] = []  # indices into playlist for current phase
var _last_similarity_tag: String = ""

# Per-game tracking
var _game_count: float = 0.0      # games completed this run (drives per-game bonus)
var _game_multiplier: float = 1.0  # current game's own multiplier (resets each game)
var _game_start_time: float = 0.0 # when current game started (seconds since epoch)
var _current_time_limit: float = 0.0  # time limit for current game (0 = no limit)
var _timed_out: bool = false      # true when current game ended via time limit

@onready var _game_container: Node2D = $GameContainer
@onready var _boot_screen: Control = $BootScreen
@onready var _game_over_screen: Control = $GameOverScreen
@onready var _music_player = $ArcadeMusic

var _crt_controller: Node2D = null
var _effect_tween: Tween = null
var _modifier_manager: Node = null
var _pending_unlocks: Array[String] = []
var _last_run_score: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# GameOverScreen starts off-screen below viewport
	_game_over_screen.position.y = VIEWPORT_HEIGHT
	# Create CRT controller programmatically (self-building Node2D with high z_index)
	_crt_controller = Node2D.new()
	_crt_controller.name = "CRTController"
	_crt_controller.set_script(load("res://Scripts/Flow/crt_controller.gd"))
	add_child(_crt_controller)
	
	# Create modifier manager
	_modifier_manager = Node.new()
	_modifier_manager.name = "ModifierManager"
	_modifier_manager.set_script(load("res://Scripts/Hub/modifier_manager.gd"))
	add_child(_modifier_manager)
	_modifier_manager.set_orchestrator(self)
	
	# Hook up defeat synth — its _ready() ran before ours (children first),
	# so source_node was null. Set it and connect the signal manually.
	$DefeatSound.source_node = self
	if not game_defeat.is_connected($DefeatSound._on_signal):
		game_defeat.connect($DefeatSound._on_signal)
	
	# Read active modifiers from save data (overrides editor exports)
	_apply_save_modifiers()
	
	# Crunch Time overrides starting lives to 1
	_lives = 1 if crunch_time else starting_lives
	
	_show_boot_screen()

func _input(event: InputEvent) -> void:
	# Ignore all input during transitions
	if _state == OrchestratorState.TRANSITIONING:
		return

	match _state:
		OrchestratorState.BOOT:
			if event.is_action_pressed("start") or event.is_action_pressed("coin"):
				_start_next_game()
				get_viewport().set_input_as_handled()
		OrchestratorState.GAME_OVER:
			if event.is_action_pressed("start") or event.is_action_pressed("coin"):
				# Block restart if game-over screen is in initials-entry phase
				if _game_over_screen.has_method("is_entering_initials") and _game_over_screen.is_entering_initials():
					return
				_restart_run()
				get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if _state == OrchestratorState.PLAYING and _current_time_limit > 0.0:
		var elapsed = Time.get_ticks_msec() / 1000.0 - _game_start_time
		if elapsed >= _current_time_limit:
			_on_time_limit_reached()

# --- State transitions ---

func _show_boot_screen() -> void:
	_state = OrchestratorState.BOOT
	state_changed.emit(CommonEnums.State.ATTRACT)
	_boot_screen.visible = true
	# Start music at idle volume (MusicPlayer handles its own internals)
	_music_player.start()
	_music_player.fade_to(music_idle_volume_db, music_fade_out_duration)

func _start_next_game() -> void:
	if playlist.is_empty():
		push_error("ArcadeOrchestrator: playlist is empty")
		return
	
	# Re-read modifiers from save data (player may have toggled on boot screen)
	_apply_save_modifiers()
		
	var entry: ArcadeGameEntry
	
	if playlist_mode == PlaylistMode.SHUFFLE:
		if _shuffle_bag.is_empty():
			_refill_shuffle_bag()
		entry = playlist[_shuffle_bag.pop_front()]
	elif playlist_mode == PlaylistMode.SEMI_RANDOM:
		entry = _get_semi_random_entry()
	else:
		if _current_index >= playlist.size():
			_current_index = 0
		entry = playlist[_current_index]
	
	_state = OrchestratorState.TRANSITIONING
	
	# Store time limit from entry for this game
	_current_time_limit = entry.time_limit
	
	# Setup new game in its own isolated SubViewport
	var new_vpc: SubViewportContainer = _setup_game_viewport(entry)
	
	# Determine what's sliding out (old game viewport or boot screen)
	var outgoing: CanvasItem
	if _active_vpc:
		outgoing = _active_vpc
	else:
		outgoing = _boot_screen
	
	# Start scrolling transition: old slides up, new slides in from below
	_scroll_transition(outgoing, new_vpc, _on_transition_to_game.bind(new_vpc))

func _on_transition_to_game(new_vpc: SubViewportContainer) -> void:
	# Free old game's viewport container (completely isolated, no physics leak)
	if _active_vpc:
		_active_vpc.queue_free()
	_active_vpc = new_vpc
	
	# Extract game instance from the viewport
	var new_instance := _get_game_from_vpc(new_vpc)
	_current_interface = null
	
	# Stop modifier listening for old game
	_modifier_manager.stop_listening()
	
	# Boot screen is now off-screen, hide it to clean up
	_boot_screen.visible = false
	
	# Finalize: start the game
	_finalize_game_start(new_instance)

func _show_game_over() -> void:
	_state = OrchestratorState.TRANSITIONING
	
	# Report score to SaveData for progression
	_last_run_score = _running_score
	_pending_unlocks = SaveData.add_score(_running_score)
	var is_new_hs: bool = SaveData.is_new_high_score(_running_score)
	
	# Notify game-over screen before slide
	if _game_over_screen.has_method("setup"):
		_game_over_screen.setup(_last_run_score, is_new_hs, _pending_unlocks)
	
	# Update final score label before slide
	var final_score_label: Label = _game_over_screen.get_node_or_null("FinalScoreLabel")
	if final_score_label:
		final_score_label.text = "FINAL SCORE: %d" % _running_score
	
	# Apply VFX to outgoing game (plays during transition)
	_apply_result_effects()
	
	# Scroll: current game viewport slides up, GameOverScreen slides in from below
	_scroll_transition(_active_vpc, _game_over_screen, _on_transition_to_game_over)

func _on_transition_to_game_over() -> void:
	# Free the game viewport
	if _active_vpc:
		_active_vpc.queue_free()
		_active_vpc = null
	_current_game_instance = null
	_current_interface = null
	
	# Fade music to idle volume on game over
	_music_player.fade_to(music_idle_volume_db, music_fade_out_duration)
	
	_state = OrchestratorState.GAME_OVER
	state_changed.emit(CommonEnums.State.GAME_OVER)

func _restart_run() -> void:
	_state = OrchestratorState.TRANSITIONING
	
	# Reset all run state; Crunch Time overrides starting lives to 1
	_lives = 1 if _modifier_manager.is_crunch_time() else starting_lives
	_running_score = 0
	_current_index = 0
	_shuffle_bag.clear()
	_sr_phase = 0
	_sr_games_played_in_phase = 0
	_sr_phase_bag.clear()
	_last_similarity_tag = ""
	_game_count = 0
	_game_multiplier = 1.0
	lives_changed.emit(_lives)
	on_points_changed.emit(0)
	on_multiplier_changed.emit(1.0 * _modifier_manager.get_score_multiplier())
	var ugs = _get_current_ugs()
	if ugs:
		ugs.set_arcade_bonus(0.0)
	
	# Advance to next music track (shows credit, starts idle section)
	_music_player.advance_track()
	
	# Scroll: GameOverScreen slides up, BootScreen slides in from below
	_boot_screen.position.y = VIEWPORT_HEIGHT
	_boot_screen.visible = true
	_scroll_transition(_game_over_screen, _boot_screen, _on_transition_to_boot)

func _on_transition_to_boot() -> void:
	_state = OrchestratorState.BOOT
	state_changed.emit(CommonEnums.State.ATTRACT)

# --- SubViewport Game Setup ---

func _setup_game_viewport(entry: ArcadeGameEntry) -> SubViewportContainer:
	# Create a SubViewportContainer + SubViewport to isolate the game
	var vpc := SubViewportContainer.new()
	vpc.name = "GameViewportContainer"
	vpc.size = GAME_SIZE
	vpc.position = Vector2.ZERO
	vpc.stretch = true
	
	var sub_vp := SubViewport.new()
	sub_vp.name = "GameViewport"
	sub_vp.size = GAME_SIZE
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_vp.transparent_bg = true
	vpc.add_child(sub_vp)
	
	# Instantiate the game scene
	var instance: Node2D = entry.game_scene.instantiate()
	
	# Get the UGS and configure for arcade mode BEFORE adding to tree
	var ugs: UniversalGameScript = instance as UniversalGameScript
	if not ugs:
		ugs = _find_ugs(instance)
	
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
		_apply_overrides(instance, entry.overrides)
	
	# Add game to SubViewport — _ready() won't fire yet (VPC not in tree)
	sub_vp.add_child(instance)
	
	# Apply setup-time modifiers (Feature Creep, Overclocked CPU, Scope Creep)
	_modifier_manager.apply_setup_modifiers(instance)
	
	# Position below viewport for slide-in
	vpc.position.y = VIEWPORT_HEIGHT
	
	# Add viewport container to game container — NOW _ready() fires for all children
	_game_container.add_child(vpc)
	
	# Take over Interface AFTER _ready() has connected UGS→Interface signals,
	# so we can properly disconnect them and reconnect to AO signals instead
	if ugs:
		_takeover_interface(ugs)
	
	
	return vpc

# Extract the game Node2D from a SubViewportContainer
func _get_game_from_vpc(vpc: SubViewportContainer) -> Node2D:
	if not vpc:
		return null
	var sub_vp = vpc.get_child(0) as SubViewport
	if not sub_vp:
		return null
	for child in sub_vp.get_children():
		if child is Node2D:
			return child
	return null

# --- Game Start ---

func _finalize_game_start(instance: Node2D) -> void:
	_current_game_instance = instance
	# Game is at origin inside its SubViewport
	if _current_game_instance:
		_current_game_instance.position.y = 0.0
	
	# Reset per-game state
	_game_multiplier = 1.0
	_game_start_time = Time.get_ticks_msec() / 1000.0
	_timed_out = false
	
	# Start listening for runtime modifiers (Shotgun, Overclocked, Scope Creep)
	_modifier_manager.start_listening()
	
	var ugs = _get_ugs_from(instance)
	if ugs:
		# Show combined multiplier (game's + per-game bonus), with Crunch Time ×3
		var display_mult: float = (_game_multiplier + _game_count) * _modifier_manager.get_score_multiplier()
		on_multiplier_changed.emit(display_mult)
		
		# Notify UGS of arcade bonus so scoring is affected
		ugs.set_arcade_bonus(float(_game_count))
		
		# Start the game (unpauses tree, sets PLAYING state)
		ugs.start_game()
	
	_state = OrchestratorState.PLAYING
	
	# Fade music up to gameplay volume
	_music_player.fade_to(music_volume_db, music_fade_in_duration)
	
	# Emit PLAYING AFTER game is started so Interface can discover timers in the tree
	state_changed.emit(CommonEnums.State.PLAYING)
	
	if playlist_mode == PlaylistMode.IN_ORDER:
		_current_index += 1

func _on_game_victory() -> void:
	_last_game_won = true
	game_victory.emit()

func _on_game_defeat() -> void:
	_last_game_won = false
	game_defeat.emit()

func _apply_result_effects() -> void:
	if not _current_game_instance:
		return
	
	# Kill any previous effect tween
	if _effect_tween and _effect_tween.is_valid():
		_effect_tween.kill()
	
	var total_duration: float = transition_duration
	
	if _last_game_won:
		# Victory: overbright modulate → CRT bloom picks up bright pixels and spreads them
		_effect_tween = create_tween()
		_effect_tween.tween_property(_current_game_instance, "modulate", Color(3.0, 3.0, 2.5, 1.0), total_duration)
	else:
		# Defeat: red tint on game, horizontal shake on viewport container
		_current_game_instance.modulate = Color(1.5, 0.2, 0.2, 1.0)
		_effect_tween = create_tween()
		_effect_tween.set_loops(15)
		_effect_tween.tween_property(_active_vpc, "position:x", 4.0, 0.03).set_trans(Tween.TRANS_SINE)
		_effect_tween.tween_property(_active_vpc, "position:x", -4.0, 0.03).set_trans(Tween.TRANS_SINE)

func _on_game_over_signal(final_score: int) -> void:
	# Stop modifier listening before processing result
	_modifier_manager.stop_listening()
	
	# Increment game count only on victory (drives per-game multiplier bonus)
	if _last_game_won:
		_game_count += _modifier_manager.get_game_count_increment()
	
	# Update UGS arcade bonus for scoring during this game
	var ugs = _get_current_ugs()
	if ugs:
		ugs.set_arcade_bonus(float(_game_count))
	
	# Time bonus only awarded on victory, scaled by current game count
	var time_bonus: int = 0
	if _last_game_won:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _game_start_time
		var base_bonus = _calc_time_bonus(elapsed)
		time_bonus = int(base_bonus * _game_count)
	
	# Apply Crunch Time score multiplier
	var crunch_mult: float = _modifier_manager.get_score_multiplier()
	
	# Apply time bonus and game score to running total
	_running_score += int((final_score + time_bonus) * crunch_mult)
	on_points_changed.emit(_running_score)
	
	if not _last_game_won and not _timed_out:
		_lives -= 1
		lives_changed.emit(_lives)
	
	# Apply VFX to outgoing game, then defer transition to avoid physics flush errors
	_apply_result_effects()
	
	if _lives > 0:
		call_deferred("_start_next_game")
	else:
		call_deferred("_show_game_over")

func _on_game_points_changed(new_score: int) -> void:
	# Game emits its own score changes — update running total live
	# Crunch Time: apply score multiplier to live display
	var crunch_mult: float = _modifier_manager.get_score_multiplier()
	on_points_changed.emit(_running_score + int(new_score * crunch_mult))

func _on_game_multiplier_changed(new_multiplier: float) -> void:
	_game_multiplier = new_multiplier
	# Combine game's multiplier with per-game bonus, apply Crunch Time ×3
	var crunch_mult: float = _modifier_manager.get_score_multiplier()
	on_multiplier_changed.emit((_game_multiplier + _game_count) * crunch_mult)

func _on_game_lives_changed(_new_lives: int) -> void:
	lives_changed.emit(_lives)

# --- Scrolling Transition ---

func _scroll_transition(outgoing: CanvasItem, incoming: CanvasItem, on_complete: Callable) -> void:
	# Kill any existing tween
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	
	# Ensure incoming is visible and positioned below viewport
	incoming.visible = true
	incoming.position.y = VIEWPORT_HEIGHT
	
	# Create parallel tween: old slides up, new slides in
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(outgoing, "position:y", -VIEWPORT_HEIGHT, transition_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.tween_property(incoming, "position:y", 0.0, transition_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_parallel(false)
	_transition_tween.tween_callback(on_complete)

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
	iface.set_multiplier((1.0 + _game_count) * _modifier_manager.get_score_multiplier())
	iface.set_lives(_lives)
	iface.animate_score = true
	
	# Show play UI immediately so Interface is visible during slide-in
	iface.hide_element(iface.elements.ATTRACT_TEXT)
	iface._show_play_ui()

# --- Helpers ---

func _get_current_ugs() -> UniversalGameScript:
	return _get_ugs_from(_current_game_instance)

func _get_ugs_from(instance: Node2D) -> UniversalGameScript:
	if not instance:
		return null
	var ugs = instance as UniversalGameScript
	if not ugs:
		ugs = _find_ugs(instance)
	return ugs

func _find_ugs(node: Node) -> UniversalGameScript:
	if node is UniversalGameScript:
		return node
	for child in node.get_children():
		var result = _find_ugs(child)
		if result:
			return result
	return null

# Force-end the current game when time limit is reached.
# Bypasses defeat/victory flow entirely: no life lost, no VFX, no time bonus.
# Just collects whatever score the player earned and instantly swipes to next game.
func _on_time_limit_reached() -> void:
	if _state != OrchestratorState.PLAYING:
		return
	_timed_out = true
	_last_game_won = false
	
	# Stop modifier listening
	_modifier_manager.stop_listening()
	
	# Collect whatever score the player earned (no time bonus)
	var ugs = _get_current_ugs()
	if ugs:
		var crunch_mult: float = _modifier_manager.get_score_multiplier()
		_running_score += int(ugs.current_score * crunch_mult)
		on_points_changed.emit(_running_score)
		_disconnect_ugs_signals(ugs)
	
	# Defer to avoid physics flush errors (called from _physics_process)
	call_deferred("_start_next_game")

func _disconnect_ugs_signals(ugs: UniversalGameScript) -> void:
	if ugs.victory.is_connected(_on_game_victory):
		ugs.victory.disconnect(_on_game_victory)
	if ugs.defeat.is_connected(_on_game_defeat):
		ugs.defeat.disconnect(_on_game_defeat)
	if ugs.on_game_over.is_connected(_on_game_over_signal):
		ugs.on_game_over.disconnect(_on_game_over_signal)
	if ugs.on_points_changed.is_connected(_on_game_points_changed):
		ugs.on_points_changed.disconnect(_on_game_points_changed)
	if ugs.on_multiplier_changed.is_connected(_on_game_multiplier_changed):
		ugs.on_multiplier_changed.disconnect(_on_game_multiplier_changed)
	if ugs.lives_changed.is_connected(_on_game_lives_changed):
		ugs.lives_changed.disconnect(_on_game_lives_changed)

func _calc_time_bonus(elapsed: float) -> int:
	# 100 points at ≤10s, linearly to 0 at ≥30s
	if elapsed <= 10.0:
		return 100
	elif elapsed >= 30.0:
		return 0
	else:
		return int((1.0 - (elapsed - 10.0) / 20.0) * 100.0)

func _apply_overrides(game_instance: Node, overrides: Array[PropertyOverride]) -> void:
	for prop_override: PropertyOverride in overrides:
		if prop_override.node_path.is_empty():
			continue
		var target_node = game_instance.get_node_or_null(prop_override.node_path)
		if target_node:
			target_node.set(prop_override.property_name, prop_override.value)
		else:
			push_warning("ArcadeOrchestrator: override node '%s' not found in game scene" % prop_override.node_path)

# --- Save Data Integration ---

func _apply_save_modifiers() -> void:
	var mods: Dictionary = SaveData.get_active_modifiers()
	shotgun_mode = mods.get("shotgun_mode", false)
	overclocked_cpu = mods.get("overclocked_cpu", false)
	feature_creep = mods.get("feature_creep", false)
	crunch_time = mods.get("crunch_time", false)
	scope_creep = mods.get("scope_creep", false)

# --- Semi-Random Playlist ---
# Phases: 0=REMAKE×2, 1=LITE_REMIX×2, 2=REMAKE+LITE×4, 3=HEAVY×2, 4=ALL(endless)
# Anti-repetition: blocks games with the same similarity_tag as the previous game.

func _get_semi_random_entry() -> ArcadeGameEntry:
	# If bag is empty, advance phase or refill
	if _sr_phase_bag.is_empty():
		_sr_advance_phase()
		_sr_refill_phase_bag()
	
	# Pop entries until we find one that passes the similarity check
	var set_aside: Array[int] = []
	var result_idx: int = -1
	
	while not _sr_phase_bag.is_empty():
		var idx: int = _sr_phase_bag.pop_front()
		if not _is_too_similar(playlist[idx]):
			result_idx = idx
			break
		else:
			set_aside.append(idx)
	
	# If nothing passed the check, use the first set-aside entry (never hard-lock)
	if result_idx == -1 and not set_aside.is_empty():
		result_idx = set_aside.pop_front()
	
	# Put remaining set-aside entries back at the end of the bag
	_sr_phase_bag.append_array(set_aside)
	
	var entry := playlist[result_idx]
	_last_similarity_tag = entry.similarity_tag
	_sr_games_played_in_phase += 1
	return entry

func _is_too_similar(entry: ArcadeGameEntry) -> bool:
	return entry.similarity_tag != "" and entry.similarity_tag == _last_similarity_tag

func _sr_advance_phase() -> void:
	# Check if current phase is exhausted
	var count := _sr_get_count_for_phase(_sr_phase)
	if _sr_games_played_in_phase >= count:
		_sr_phase += 1
		_sr_games_played_in_phase = 0
		# Phase 4 is endless — stays at 4 forever

func _sr_refill_phase_bag() -> void:
	_sr_phase_bag.clear()
	var buckets := _sr_get_buckets_for_phase(_sr_phase)
	for i in playlist.size():
		if playlist[i].bucket in buckets:
			_sr_phase_bag.append(i)
	_sr_phase_bag.shuffle()

func _sr_get_buckets_for_phase(phase: int) -> Array[int]:
	match phase:
		0:  # Remakes only
			return [ArcadeGameEntry.GameBucket.REMAKE]
		1:  # Lite remixes only
			return [ArcadeGameEntry.GameBucket.LITE_REMIX]
		2:  # Remakes + lite remixes combined
			return [ArcadeGameEntry.GameBucket.REMAKE, ArcadeGameEntry.GameBucket.LITE_REMIX]
		3:  # Heavy remixes / originals
			return [ArcadeGameEntry.GameBucket.HEAVY_REMIX_ORIGINAL]
		_:  # Phase 4+: all buckets (endless)
			return [ArcadeGameEntry.GameBucket.REMAKE, ArcadeGameEntry.GameBucket.LITE_REMIX, ArcadeGameEntry.GameBucket.HEAVY_REMIX_ORIGINAL]

func _sr_get_count_for_phase(phase: int) -> int:
	match phase:
		0: return 2   # 2 remakes
		1: return 2   # 2 lite remixes
		2: return 4   # 4 mixed (remakes + lite)
		3: return 2   # 2 heavy
		_: return 999 # Phase 4+: endless (never auto-advances)

func _refill_shuffle_bag() -> void:
	_shuffle_bag.clear()
	_shuffle_bag.resize(playlist.size())
	for i in playlist.size():
		_shuffle_bag[i] = i
	_shuffle_bag.shuffle()
