# Plan 17 — Arcade Juice Post-Launch

**Created:** 2026-05-06  
**Updated:** 2026-05-15  
**Status:** Pending (after itch demo launch)  
**Scope:** Phases 1–4 (AO Decomposition, VRAM Boot, Attract Mode, Coin Drop)  
**Source:** Phase 1 extracted from AO audit (Plan 15 context); Phases 2–4 extracted from Plan 14 (Arcade Juice & Attract Mode)  
**Depends on:** Plan 15 complete (Polybius + itch demo shipped)

---

## Goal

Four post-launch polish layers that transform the arcade from a functional game sequencer into an authentic-feeling arcade experience:

1. **Arcade Orchestrator Decomposition** — Break the monolithic 420-line AO into focused components. The AO should only manage playlist → load → play → end → next.
2. **VRAM Boot Screen** — An animated boot sequence that mimics a cabinet powering on from cold boot.
3. **Attract Mode System** — AI-controlled demos that play during transitions and while waiting for the player to press Start.
4. **Coin Drop Boot Sequence** — A millisecond-level choreography when the player presses Start, mimicking hardware initializing.

All changes must run at 60fps in WebGL compatibility mode.

---

## Phase 1 — Arcade Orchestrator Decomposition

### Goal

Break the 420-line monolithic `arcade_orchestrator.gd` into focused components. The AO should only be responsible for: **taking a playlist and managing the lifecycle of the games**. Everything else (scoring, lives, transitions, interface wiring, CRT setup) becomes a child component that listens to AO state changes.

### Current State Audit

The AO currently owns 13 distinct responsibilities:

| # | Responsibility | Lines | Verdict |
|---|---|---|---|
| 1 | State machine (BOOT/PLAYING/RESULT/GAME_OVER/TRANSITIONING) | ~90 | **STAYS** — core lifecycle |
| 2 | Playlist selection (IN_ORDER/SHUFFLE, index, shuffle bag) | ~30 | **STAYS** — core lifecycle |
| 3 | Game instance lifecycle (setup, finalize, free) | ~65 | **STAYS** — core lifecycle |
| 4 | UGS wiring (connect signals, set ARCADE mode) | ~30 | **STAYS** — core lifecycle |
| 5 | Scoring + multiplier + time bonus | ~70 | **EXTRACT → ArcadeScorer** |
| 6 | Lives tracking | ~15 | **EXTRACT → LivesCounter (wired to AO)** |
| 7 | Interface takeover (signal swap, display mode, initial values) | ~40 | **EXTRACT → ArcadeInterfaceBridge** |
| 8 | Scrolling transitions (tween, position manipulation) | ~30 | **EXTRACT → ArcadeTransition** |
| 9 | Music fade control (4 scattered fade_to calls) | ~12 | **EXTRACT → MusicPlayer listens to state_changed** |
| 10 | CRT controller creation (programmatic Node2D + script) | ~4 | **MOVE to scene tree** |
| 11 | Shuffle bag logic | ~6 | **STAYS** (tiny, playlist-adjacent) |
| 12 | Property override application | ~9 | **STAYS** (tiny, lifecycle-adjacent) |
| 13 | UGS tree discovery helpers | ~20 | **MOVE to UGS as static methods** |

### Target: AO shrinks from ~420 lines → ~180–200 lines

### New Components

#### 1. `ArcadeScorer` (new Hub script)

**Extracts:** Scoring, multiplier, time bonus, game count tracking

**Exports:**
- `time_bonus_max: int = 100` — max time bonus points
- `time_bonus_fast_threshold: float = 10.0` — seconds for max bonus
- `time_bonus_slow_threshold: float = 30.0` — seconds for zero bonus

**Signals (replace AO's current `on_points_changed` / `on_multiplier_changed`):**
- `on_points_changed(new_score: int)`
- `on_multiplier_changed(new_multiplier: float)`

**State:**
- `_running_score: int`
- `_game_count: int` — games completed this run
- `_game_multiplier: float` — current game's own multiplier
- `_game_start_time: float` — when current game started

**Methods:**
- `reset_run()` — zero everything
- `begin_game()` — record start time, reset per-game multiplier
- `record_result(won: bool, final_score: int)` — apply time bonus if won, update running score, increment game count
- `get_running_score() -> int`
- `get_combined_multiplier() -> float` — returns `_game_multiplier + _game_count`
- `get_game_count() -> int` — for UGS arcade bonus passthrough
- `update_game_multiplier(new_multiplier: float)` — live relay from UGS
- `update_live_score(game_score: int)` — live relay: `_running_score + game_score`

**Internal:** `_calc_time_bonus(elapsed: float) -> int`

**Wiring:** AO connects UGS `on_points_changed` → `scorer.update_live_score()`, UGS `on_multiplier_changed` → `scorer.update_game_multiplier()`, and relays `scorer.on_points_changed` / `scorer.on_multiplier_changed` to the InterfaceBridge.

#### 2. Lives Tracking → `LivesCounter` component wired to AO

The existing `LivesCounter` component already tracks lives with `lives_changed` signals. Instead of managing lives in the AO:

- Add an `ArcadeLivesCounter` (or repurpose the existing `lives_counter.gd`) as a child of the AO scene
- Wire it to the AO's state: AO emits a signal when a game is lost → LivesCounter decrements
- AO queries `lives_counter.any_lives_left()` to decide next state
- LivesCounter's `lives_changed` signal connects directly to InterfaceBridge

This keeps the pattern consistent with how lives work in-game (LivesCounter component) but wired to the AO's run lifecycle instead of a single game.

#### 3. `ArcadeInterfaceBridge` (new Hub script)

**Extracts:** Interface takeover logic

**Methods:**
- `takeover(ugs: UniversalGameScript, scorer: ArcadeScorer, lives_counter)` — disconnect Interface from UGS, connect to scorer + lives_counter signals, set display mode, push initial values
- `release()` — cleanup (optional, happens automatically when game is freed)

**The bridge replaces the 40-line `_takeover_interface()` method with a single call.**

#### 4. `ArcadeTransition` (new Hub script)

**Extracts:** Scrolling transition tween logic

**Exports:**
- `transition_duration: float = 0.4`

**Methods:**
- `scroll(outgoing: CanvasItem, incoming: CanvasItem, on_complete: Callable)` — parallel tween, old slides up, new slides in

**Replaces the 15-line `_scroll_transition()` and the `_transition_tween` variable.**

#### 5. Music Fades → MusicPlayer listens to `state_changed`

**No new component.** The AO already emits `state_changed(CommonEnums.State)` at every transition. The MusicPlayer gains an export group for volume mappings:

```gdscript
@export_group("Arcade Fade")
@export var arcade_play_volume_db: float = -10.0
@export var arcade_idle_volume_db: float = -20.0
@export var arcade_fade_in_duration: float = 1.0
@export var arcade_fade_out_duration: float = 0.5
```

When connected to the AO's `state_changed`, it fades to the appropriate volume. Remove the 4 music-related exports from the AO and the scattered `fade_to()` calls.

#### 6. CRT Controller → Scene tree

Move the programmatic CRT creation (lines 61–64 of current AO) into `arcade_orchestrator.tscn` as a direct child node. No code change needed — just add the node in the editor.

#### 7. UGS Discovery → Static methods on `UniversalGameScript`

Move `_find_ugs(node)` and `_get_ugs_from(instance)` from the AO to `UniversalGameScript` as static methods:

```gdscript
static func find_ugs(node: Node) -> UniversalGameScript
static func get_ugs_from(instance: Node2D) -> UniversalGameScript
```

These are useful outside the AO (e.g., any component that needs to walk up to the UGS).

### New/Modified Files

| File | Action | Purpose |
|------|--------|---------|
| `Scripts/Hub/arcade_scorer.gd` | **NEW** | Score/multiplier/time bonus tracking |
| `Scripts/Hub/arcade_interface_bridge.gd` | **NEW** | Interface takeover signal swap |
| `Scripts/Hub/arcade_transition.gd` | **NEW** | Scrolling transition tween |
| `Scripts/Hub/arcade_orchestrator.gd` | **MODIFY** | Strip to lifecycle-only, use new components |
| `Scenes/Hub/arcade_orchestrator.tscn` | **MODIFY** | Add CRT controller node, add new component nodes |
| `Scripts/Flow/music_player.gd` | **MODIFY** | Add arcade volume mappings, listen to state_changed |
| `Scripts/Core/universal_game_script.gd` | **MODIFY** | Add static `find_ugs()` / `get_ugs_from()` |

### Post-Refactor AO Shape

```gdscript
# AO _on_game_over_signal becomes:
func _on_game_over_signal(final_score: int) -> void:
    _scorer.record_result(_last_game_won, final_score)
    _state = OrchestratorState.RESULT
    _result_timer = 0.5

# RESULT handler becomes:
if _result_timer <= 0.0:
    if _lives_counter.any_lives_left():
        _start_next_game()
    else:
        _show_game_over()

# _start_next_game transition becomes:
_transition.scroll(outgoing, new_instance, _on_transition_to_game.bind(new_instance))

# _finalize_game_start becomes:
func _finalize_game_start(instance: Node2D) -> void:
    _current_game_instance = instance
    _current_game_instance.position.y = 0.0
    _scorer.begin_game()
    var ugs = UniversalGameScript.get_ugs_from(instance)
    if ugs:
        ugs.set_arcade_bonus(float(_scorer.get_game_count()))
        ugs.start_game()
    _state = OrchestratorState.PLAYING
    state_changed.emit(CommonEnums.State.PLAYING)
    if playlist_mode == PlaylistMode.IN_ORDER:
        _current_index += 1
```

### Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| 1a | Add static `find_ugs()` / `get_ugs_from()` to UGS | — |
| 1b | Create `ArcadeScorer` script | — |
| 1c | Create `ArcadeTransition` script | — |
| 1d | Create `ArcadeInterfaceBridge` script | 1b |
| 1e | Add arcade volume mappings to MusicPlayer | — |
| 1f | Move CRT controller to scene tree | — |
| 1g | Refactor `arcade_orchestrator.gd` — strip to lifecycle, wire new components | 1a–1f |
| 1h | Update `arcade_orchestrator.tscn` — add component nodes | 1g |
| 1i | Wire LivesCounter to AO signals | 1g |
| 1j | Playtest full arcade run — verify identical behavior | all above |

### Risks & Considerations

1. **Signal chain length** — The relay chain gets longer: `UGS → AO → Scorer → InterfaceBridge → Interface`. Each hop is a single connection, but debugging signal flow requires following more indirection. The AO becomes a thin router.

2. **LivesCounter reuse** — The existing `lives_counter.gd` is designed for in-game use (decrements on `lives_depleted` signal). The arcade LivesCounter needs different triggers (AO "game lost" signal). Could be a separate lightweight script or a configured instance of the existing one.

3. **No functional changes** — This refactoring must produce identical observable behavior. All scores, transitions, music fades, and CRT effects should be unchanged. Playtest before and after.

4. **Polybius integration** — Plan 15 Phase 2 adds the INTRO state and Polybius callbacks to the AO. This refactoring should account for those hooks (the AO's state_changed signal is what Polybius listens to, so the decomposition is additive-friendly).

---

## Phase 2 — VRAM Boot Screen

### Goal

Replace the placeholder `boot_screen.tscn` ("CD50 ARCADE" static text) with an animated boot sequence that mimics a cabinet powering on from cold boot. Also serves as the web loading screen — the scene is tiny (just code), so it loads instantly while the rest of the game downloads.

### Implementation: `vram_boot.gd`

A script on the BootScreen that:

1. **On `_ready()`**, begins drawing random colored rectangles at random coordinates using `_draw()`. Classic Taito/Nintendo VRAM palette: pinks, cyans, magentas, lime greens. The blocks flicker and change position each frame.
2. **Plays a harsh 60Hz electrical hum** via `sound_synth` (sine wave, low frequency, very quiet).
3. **After 1.5 seconds** (or configurable duration), the random blocks snap into the "CD50 ARCADE" logo. The hum drops to silence.
4. **Transitions to AO's BOOT state** — the existing "PRESS START" prompt appears.

The current static BootScreen becomes this animated version. The scene structure stays the same (ColorRect + Labels), just the script drives the animation.

### New/Modified Files

| File | Changes |
|------|---------|
| `boot_screen.tscn` | Add `vram_boot.gd` script, restructure for animation |
| `vram_boot.gd` | `Scripts/Hub/` — Animated boot sequence script |

### Deliverable

Player opens the game → sees random VRAM blocks flickering → blocks snap to "CD50 ARCADE" → "PRESS START" appears. Feels like a real cabinet powering on. Works as web loading screen.

---

## Phase 3 — Attract Mode System

### Goal

Each game shows an AI-controlled demo during transitions and while waiting for the player to press Start. The attract stub is visible as the game scrolls up into position, creating the illusion of a real cabinet cycling through demos.

### Architecture: UGS-Managed Attract

Attract mode is owned by the **UGS**, not the AO. This preserves standalone/arcade parity — running `space_rocks.tscn` in the editor shows the same attract demo as the arcade cabinet.

**Key change to AO flow:** The AO no longer hides or pauses the next game during transitions. Instead:
1. AO instances the game scene and adds it to the tree
2. UGS `_ready()` runs, initializes in ATTRACT state
3. UGS attract code hides the real game tree, spawns the attract stub
4. AO's scroll transition moves the game into position — the player sees the attract stub playing
5. When the player presses Start, AO calls `start_game()` → UGS transitions to PLAYING
6. Attract stub is killed, real game tree is revealed, boot sequence fires

### Changes to `universal_game_script.gd`

```gdscript
@export var attract_scene: PackedScene

var _attract_instance: Node2D = null

func _enter_attract():
    # Hide the real game tree (saves draw calls, clean visual)
    visible = false
    # Spawn attract stub as sibling so it draws on top
    if attract_scene:
        _attract_instance = attract_scene.instantiate()
        get_parent().call_deferred("add_child", _attract_instance)

func _exit_attract():
    # Kill the stub
    if _attract_instance:
        _attract_instance.queue_free()
        _attract_instance = null
    # Reveal the real game tree
    visible = true
```

The state machine already handles ATTRACT → PLAYING transitions. The `_enter_attract` / `_exit_attract` hooks plug into the existing `state_changed` handler.

**Standalone mode:** UGS starts in ATTRACT (if `attract_scene` is set). Player presses Start → transitions to PLAYING → stub dies → game boots. Identical flow to arcade mode.

### Changes to `arcade_orchestrator.gd`

- **Remove:** The code that hides/pauses the next game during scroll transitions
- **Change:** Game instances are added to tree immediately. UGS starts in ATTRACT, so the attract stub plays during the scroll.
- **No change to:** Scroll tween mechanics, Interface Takeover, state machine

### Creating Attract Stub Scenes

Workflow per game (~60 seconds each):

1. Duplicate `game.tscn` → `game_attract.tscn`
2. Delete `Interface` node (no UI in attract)
3. Delete `LivesCounter` (no lives in attract)
4. On player entity: Remove `player_control`, add `interceptor_ai` + `aim_ai`
5. On WaveDirector/Spawner: Remove `on_game_start` trigger, set to spawn immediately
6. In `game.tscn`: Drag `game_attract.tscn` into UGS `attract_scene` export

**Scenes to create:**

| Game | Attract Scene | AI Setup |
|------|---------------|----------|
| Paddle Ball | `paddle_ball_attract.tscn` | Both paddles: `interceptor_ai` |
| Brick Breaker | `brick_breaker_attract.tscn` | Paddle: `interceptor_ai`, remove LivesCounter |
| Space Rocks | `space_rocks_attract.tscn` | Ship: `interceptor_ai` + `aim_ai` + `gun_simple` |
| Meteor Rally | `meteor_rally_attract.tscn` | Ship: `interceptor_ai` + `aim_ai` |
| Dogfight | `dogfight_attract.tscn` | Ship: `interceptor_ai` + `aim_ai` + `gun_simple` |
| Bug Blaster | `bug_blaster_attract.tscn` | Remove player, let invaders march |
| Block Drop | `block_drop_attract.tscn` | `falling_ai` with random lateral moves |
| Rock Breaker | `rock_breaker_attract.tscn` | Paddle: `interceptor_ai` |

### New/Modified Files

| File | Changes |
|------|---------|
| `universal_game_script.gd` | Add `attract_scene` export, `_enter_attract()`, `_exit_attract()`, ATTRACT state handling |
| `arcade_orchestrator.gd` | Remove game hiding/pausing during transitions, let UGS attract system handle it |
| 8 × `*_attract.tscn` | New attract stub scenes in `Scenes/Games/` alongside originals |

### Deliverable

During scroll transitions, the player sees AI-controlled demos of the next game. In standalone mode, games play their own attract demos on launch. Pressing Start kills the stub and boots the real game. Zero attract-specific components needed — just AI brains on duplicated scenes.

---

## Phase 4 — Coin Drop Boot Sequence

### Goal

When the player presses Start (transitioning from ATTRACT to PLAYING), the real game doesn't just appear — it "boots up" with a millisecond-level choreography that mimics hardware initializing. Entities pop in with a VRAM jitter: a 1-frame position offset and desaturation, then snap to their correct state.

### 4A. `stagger_reveal.gd` — Delayed Entity Pop-In

Attached to pre-placed entities (walls, player paddle, arena borders). These start hidden and reveal on PLAYING state with configurable delays.

```gdscript
extends UniversalComponent

@export var reveal_delay: float = 0.1

func _ready():
    await get_tree().process_frame
    parent.visible = false
    if game:
        game.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state):
    if new_state == UniversalGameScript.State.PLAYING:
        game.state_changed.disconnect(_on_state_changed)
        await get_tree().create_timer(reveal_delay).timeout
        _vram_pop()
        parent.visible = true

func _vram_pop():
    var stored_pos = parent.position
    parent.position += Vector2(randi_range(-3, 3), randi_range(-3, 3))
    parent.modulate = Color(0.5, 0.5, 0.5)
    await get_tree().process_frame  # 1 frame of glitch
    parent.position = stored_pos
    parent.modulate = Color.WHITE
```

**Banks** — Multiple stagger_reveal components with increasing delays create the left-to-right pop-in effect:
- Bank 0 (0.0s): Arena walls, borders
- Bank 1 (0.05s): Player entity
- Bank 2 (0.1s+): Bricks, threats (handled by spawner stagger + vram_pop)

### 4B. `vram_pop.gd` — Dynamic Entity Glitch

Attached to body scene templates (`asteroid.tscn`, `brick.tscn`, `ball.tscn`). Fires on dynamically spawned entities — the 1-frame VRAM jitter.

```gdscript
extends UniversalComponent

func _ready():
    await get_tree().process_frame  # Wait for spawner to place body
    if not parent.visible: return   # Don't pop if hidden by stagger_reveal
    
    var stored_pos = parent.position
    parent.position += Vector2(randi_range(-3, 3), randi_range(-3, 3))
    parent.modulate = Color(0.5, 0.5, 0.5)
    await get_tree().process_frame  # 1 frame of glitch
    parent.position = stored_pos
    parent.modulate = Color.WHITE
    set_process(false)  # Dead component, no further cost
```

**Spawner synergy:** The existing `wave_spawner` stagger delay naturally sequences vram_pop activations. Space Rocks pop in one by one as they spawn. Bricks appear left-to-right. No additional timing code needed.

### 4C. Timing Choreography

The millisecond-by-millisecond "Coin Drop" sequence:

| Time | Event | Player Sees |
|------|-------|-------------|
| 0.000s | Player presses Start. UGS state → PLAYING. | Attract mode playing |
| 0.001s | Attract stub `queue_free()`'d. Real game `visible = true`. | Flash to black |
| 0.016s | stagger_reveal Bank 0 fires (arena/walls) | Arena borders snap in |
| 0.030s | Bank 0 VRAM glitch resolves | Borders snap to true position/color |
| 0.050s | Bank 1 fires (player entity) | Player appears with 1-frame jitter |
| 0.066s | Bank 1 glitch resolves | Player snaps to correct state |
| 0.100s | Spawner delay ends. Bank 2 starts spawning | Threats begin appearing |
| 0.116s | Each spawned entity hits vram_pop | Each threat pops in with micro-jitter |
| 0.300s | Final bank (ball/projectiles) spawns | Game fully live. Player has control. |

**Why this feels good:** The brain registers the sudden black screen (hardware interrupt), sees entities "write" to the screen in order, and subconsciously accepts it as a physical machine waking up. It completely bypasses the "menu fade-in" feel.

### New Files

| File | Location | Purpose |
|------|----------|---------|
| `stagger_reveal.tscn` | `Scenes/Components/` | Staggered reveal component scene |
| `stagger_reveal.gd` | `Scripts/Components/` | Delayed pop-in with VRAM jitter on PLAYING |
| `vram_pop.tscn` | `Scenes/Components/` | Dynamic entity VRAM glitch scene |
| `vram_pop.gd` | `Scripts/Components/` | 1-frame position jitter + desaturate on spawn |

### Deliverable

Pressing Start triggers a choreographed boot sequence across all games. Pre-placed entities pop in with staggered delays. Dynamically spawned entities glitch in via vram_pop. Feels like real hardware initializing. No game-specific code — purely component-driven.

---

## Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| **Phase 1 — AO Decomposition** | | |
| 1a | Add static `find_ugs()` / `get_ugs_from()` to UGS | — |
| 1b | Create `ArcadeScorer` script | — |
| 1c | Create `ArcadeTransition` script | — |
| 1d | Create `ArcadeInterfaceBridge` script | 1b |
| 1e | Add arcade volume mappings to MusicPlayer | — |
| 1f | Move CRT controller to scene tree | — |
| 1g | Refactor `arcade_orchestrator.gd` — strip to lifecycle, wire new components | 1a–1f |
| 1h | Update `arcade_orchestrator.tscn` — add component nodes | 1g |
| 1i | Wire LivesCounter to AO signals | 1g |
| 1j | Playtest full arcade run — verify identical behavior | all above |
| **Phase 2 — VRAM Boot** | | |
| 2a | Create `vram_boot.gd` animated boot script | — |
| 2b | Update `boot_screen.tscn` with boot animation | 2a |
| 2c | Test: boot animation → "PRESS START" transition | 2b |
| **Phase 3 — Attract Mode** | | |
| 3a | Add `attract_scene` export + lifecycle to UGS | — |
| 3b | Update AO: remove game hiding/pausing, let UGS attract handle it | 3a |
| 3c | Create attract stub for Paddle Ball (simplest game, proves the concept) | 3a |
| 3d | Test: Paddle Ball attract visible during scroll, dies on Start | 3b, 3c |
| 3e | Create attract stubs for remaining 7 games | 3d |
| 3f | Test: full arcade run with attract modes | 3e |
| **Phase 4 — Coin Drop** | | |
| 4a | Create `stagger_reveal` component | — |
| 4b | Create `vram_pop` component | — |
| 4c | Add stagger_reveal to Brick Breaker (best showcase: arena → paddle → bricks → ball) | 4a |
| 4d | Add vram_pop to body templates (asteroid, brick, ball) | 4b |
| 4e | Test: Brick Breaker full coin drop sequence | 4c, 4d |
| 4f | Add stagger_reveal to remaining games | 4e |
| 4g | Timing tuning pass — adjust reveal_delay per game | 4f |
| 4h | Final playtest: full arcade run with CRT + attract + boot sequence | all above |

---

## Risks & Considerations

1. **AO refactoring scope** — Phase 1 touches the core orchestrator that everything depends on. Must be tested incrementally. The signal chain gets longer (`UGS → AO → Scorer → InterfaceBridge → Interface`), so debugging requires following more indirection. The AO becomes a thin router.

2. **LivesCounter reuse** — The existing `lives_counter.gd` is designed for in-game use (decrements on `lives_depleted` signal). The arcade LivesCounter needs different triggers (AO "game lost" signal). Could be a separate lightweight script or a configured instance of the existing one.

3. **No functional changes in Phase 1** — The refactoring must produce identical observable behavior. All scores, transitions, music fades, and CRT effects should be unchanged. Playtest before and after.

4. **Polybius integration** — Plan 15 Phase 2 adds the INTRO state and Polybius callbacks to the AO. Phase 1 refactoring should account for those hooks (the AO's `state_changed` signal is what Polybius listens to, so the decomposition is additive-friendly).

5. **Attract stub AI quality** — Some games (Block Drop, Bug Blaster) are harder to make convincing AI demos for. A "bad" AI attract is fine — real arcade attract modes often showed terrible gameplay. The goal is "alive and moving," not "skilled."

6. **Two scenes in memory during attract** — The real game (hidden) + attract stub are both in the tree simultaneously. This is fine for the project's lightweight procedural scenes (~5KB RAM each). The `visible = false` on the real game saves draw calls.

7. **Attract stub collision with Interface Takeover** — The AO's Interface Takeover connects to UGS signals. In ATTRACT state, the Interface should be hidden (it's part of the real game tree, which is hidden). When PLAYING starts, the tree becomes visible and Interface Takeover proceeds as before. Need to verify this flow doesn't create a 1-frame flash of unstyled Interface.

8. **vram_pop on respawn** — Bodies that respawn (e.g., Block Drop pieces, multi-wave space_rocks) will vram_pop each time. This is actually desirable — each new piece/wave feels like the hardware is "writing" new data. But if it becomes distracting, add a `pop_only_once` flag.

---

## What Doesn't Change

- **`interface.gd`** — No modifications
- **Game scenes** — No modifications for Phases 1–3 (attract stubs are separate scenes, Phase 4 attaches components)
- **`ArcadeGameEntry` resources** — No modifications
- **AO core state machine** — Still BOOT → PLAYING → RESULT → GAME_OVER → restart
- **AO signal declarations** — Already exist (may move ownership to components)
- **Scrolling transition mechanics** — Unchanged (just extracted to ArcadeTransition component)