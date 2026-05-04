# Plan 13 — Arcade Orchestrator and Related Components

**Created:** 2026-05-03  
**Status:** Active  
**Scope:** Phases 0–3 (Input Refactoring, Shell, Run, Fast Rules)  
**Source:** `planning/brainstorming/itch build.md`

---

## Goal

Build the architecture for an itch.io arcade demo: a meta-level orchestrator that loads existing games in sequence, runs them with fast rules, tracks lives and score across the run, and provides a complete boot → play → game over → replay loop.

This plan also includes a prerequisite **Input Refactoring** pass that moves all input handling to Godot's Input Map properly, and a **UGS Mode** system that allows games to behave differently when run standalone vs. under orchestrator control.

---

## Phase 0 — Input Refactoring (Prerequisite)

### Why Now

Currently, input is handled in two places:
- `player_control.gd` uses `_unhandled_input` for button events and `Input.get_axis()` for analog
- `universal_game_script.gd` uses `_unhandled_input` for start/restart/quit

This creates conflicts when the orchestrator needs to intercept "start" and "coin" inputs. The arcade mode needs dedicated `start` and `coin` actions in the Input Map. This refactoring clears the path for all future work (key rebinding, multiple control schemes, etc.).

### Input Map Additions

New actions to register in `project.godot`:
- `start` — Confirms menus, starts game (Enter, Start button on gamepad)
- `coin` — Inserts coin / arcade meta-action (C key, Select button on gamepad)
- `pause` — Pauses game (Escape, Back button on gamepad)

Existing actions (already defined): `button_up`, `button_down`, `button_left`, `button_right`, `button_l`, `button_r`, `aim_up`, `aim_down`, `aim_left`, `aim_right`

### Changes to `player_control.gd`

- Remove `_unhandled_input` override entirely
- In `_physics_process`, use `Input.is_action_just_pressed()` / `Input.is_action_just_released()` for button events (shoot, thrust, action)
- Continue using `Input.get_axis()` for directional input (already correct)
- Mouse motion handling: move to `_input()` (higher priority, needed for aim-to-cursor) with a guard for `using_mouse`
- Result: `player_control.gd` becomes a pure signaller — reads Input Map, emits on parent body

### Changes to `universal_game_script.gd`

- Remove `_unhandled_input` override entirely
- Add new methods: `_on_start_pressed()`, `_on_restart_pressed()` — called externally instead of capturing input directly
- The orchestrator (in ARCADE mode) or a simple input router (in STANDALONE mode) calls these methods
- For STANDALONE backward compatibility: add a small `_input()` handler that checks mode and routes `start`/`pause` actions to the appropriate methods

### New Scripts

- `Scripts/Hub/input_router.gd` (optional — could also be inline in UGS) — Centralized place that reads `start`, `coin`, `pause` from Input Map and routes them to the appropriate node based on current context (UGS in standalone, orchestrator in arcade mode)

### Deliverable

All existing games work identically to before, but input is fully Input Map-driven. `player_control.gd` has no `_unhandled_input`. UGS has no `_unhandled_input`. The Input Map has `start`, `coin`, `pause` actions ready for the orchestrator.

---

## Phase 1 — Shell: Boot, One Game In, One Game Out

### New Directory Structure

```
Scripts/Hub/         — Meta-level scripts (orchestrator, boot, scoreboard)
Scenes/Hub/          — Meta-level scenes
```

### New Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `arcade_orchestrator.gd` | `Scripts/Hub/` | State machine: BOOT → PLAYING → RESULT → GAME_OVER → RESTART. Loads games, tracks lives/score, detects game end. |
| `arcade_game_entry.gd` | `Scripts/Hub/` | Resource: PackedScene + display_name + property overrides + win_result enum. Defines a single game in the playlist. |

### New Scenes

| Scene | Location | Purpose |
|-------|----------|---------|
| `arcade_orchestrator.tscn` | `Scenes/Hub/` | Main arcade scene. Contains GameContainer, HUD, BootScreen overlay. |
| `boot_screen.tscn` | `Scenes/Hub/` | Simple "INSERT COIN / PRESS START" screen. First thing player sees. |

### Changes to `universal_game_script.gd`

Add a **Mode enum** and export:
```
enum Mode { STANDALONE, ARCADE }
@export var mode: Mode = Mode.STANDALONE
```

**STANDALONE behavior** (existing, unchanged):
- `_ready()` initializes collision matrix, connects victory/defeat
- `p1_win()` / `p1_lose()` show Interface elements
- Input router allows start/restart/quit

**ARCADE behavior** (new):
- Collision matrix setup still happens (games need collision regardless)
- `p1_win()` / `p1_lose()` suppress `$Interface` calls — just set state to GAME_OVER and emit `on_game_over`
- No input handling — orchestrator controls everything
- `start_game()` is called by the orchestrator, not by input

### Boot Screen

Simple scene, not the full CRT boot sequence (that's a juice pass for later):
- Black background
- "INSERT COIN" blinking text (uses `coin` action)
- "PRESS START" blinking text (uses `start` action)
- Either input transitions to the orchestrator's PLAYING state
- Web audio compliance: if running in web and AudioServer is inactive, show "CLICK ANYWHERE TO START" first

### Orchestrator State Machine

```
BOOT → (start/coin input) → PLAYING → (game on_game_over) → RESULT
RESULT → (lives > 0) → load next game → PLAYING
RESULT → (lives ≤ 0) → GAME_OVER
GAME_OVER → (start/coin input) → RESTART → BOOT
```

**PLAYING state:**
- Instance `ArcadeGameEntry.game_scene`, add to `GameContainer`
- Set UGS `mode = ARCADE`
- Call `ugs.start_game()`
- Connect to `ugs.on_game_over` and `ugs.victory` / `ugs.defeat`

**On game end:**
- Read `ugs.current_score`, add to `running_score`
- Determine win/loss from which signal fired (victory = win, defeat = loss)
- If loss: decrement `lives`
- Free the game instance
- Transition to RESULT

**RESULT state:**
- Brief pause (0.5s)
- Flash win/loss indicator
- If lives > 0: advance to next game → PLAYING
- If lives ≤ 0: → GAME_OVER

### HUD (Minimal)

- `LivesDisplay` — N dots (lives remaining)
- `ScoreDisplay` — Running total
- `GameTitleLabel` — Current game name (flashes on entry)

### Deliverable

Player opens scene → sees "INSERT COIN / PRESS START" → presses start → Pong loads and plays → Pong ends → score shows in HUD → orchestrator detects game over, shows result. No Polybius, no transition animation, no next game. Just the wiring.

---

## Phase 2 — The Run: Lives, Sequence, Preload, Scroll

### New Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `arcade_playlist.gd` | `Scripts/Hub/` | Resource: ordered array of ArcadeGameEntry + starting_lives + shuffle flag. |

### New Resources

- `arcade_default_playlist.tres` — Contains all working games with default (non-tuned) entries

### Features

**1. Lives system**
- `lives: int` initialized from `ArcadePlaylist.starting_lives` (default: 3)
- On game loss (defeat): `lives -= 1`
- On game win (victory): lives unchanged
- `lives ≤ 0` → GAME_OVER

**2. Game sequence**
- `current_index: int` tracks position in playlist
- After game ends: `current_index += 1`, wrap to 0 if past end
- Shuffle option on ArcadePlaylist: randomize order at boot

**3. Preloading**
- When a game starts playing: `ResourceLoader.load_threaded_request()` for next entry's scene
- On transition: `ResourceLoader.load_threaded_get()` → instance
- Fallback: if not loaded yet, show brief "LOADING" text and poll

**4. Scrolling transition**
- Next game instanced, positioned at `y = viewport_height` (below screen)
- Tween: current game `y: 0 → -viewport_height`, next game `y: viewport_height → 0`
- Duration: 0.4s, ease: cubic
- On complete: free old game, set mode on new UGS, call `start_game()`

**5. GameTitleLabel**
- Flashes the entry's `display_name` for 1.5s when a new game scrolls in
- Fades out as play begins

**6. Score carry**
- On game end: `running_score += game.current_score`
- Optional win bonus: `×2` score for winning the game
- Streak multiplier: `+0.5×` per consecutive win, resets on loss

**7. Simple Game Over screen**
- "GAME OVER" text (large, centered)
- Final score
- "INSERT COIN TO PLAY AGAIN" blinking text
- On start/coin input → reset lives, score, index → BOOT

### Deliverable

Full arcade run: games play in sequence with scrolling transitions, 3 lives, running score + multiplier. When you lose 3 games, "GAME OVER" screen with final score. Press start to play again.

---

## Phase 3 — Fast Rules: Arcade Configurations

### Goal

Every game plays FAST. Tuned for 15–45 seconds per game. A full 3-life run takes 3–8 minutes.

### Resources to Create

One `ArcadeGameEntry.tres` per game with property overrides:

| Game | Scene | Fast Rule Overrides |
|------|-------|-------------------|
| Pong | `remakes/pong.tscn` | PointsMonitor threshold → 1 |
| Breakout | `remakes/breakout.tscn` | LivesCounter lives → 1 |
| Asteroids | `remakes/asteroids.tscn` | WaveDirector max_waves → 1 |
| Pongsteroids | `remixes/pongsteroids.tscn` | PointsMonitor threshold → 1 |
| Dogfight | `originals/dogfight.tscn` | WaveDirector max_waves → 1 |
| Pongout | `remixes/pongout.tscn` | PointsMonitor threshold → 1 |
| Breaksteroids | `remixes/breaksteroids.tscn` | WaveDirector max_waves → 1, LivesCounter lives → 1 |
| Space Invaders | `remakes/space_invaders.tscn` | WaveDirector max_waves → 1 |
| Tetris | `remakes/tetris.tscn` | Starting level → 5, gravity speed → fast |

### Override Application

After instancing a game scene, iterate `entry.overrides`:
- `get_node(node_path)` on the game instance
- `set(property_name, value)` on the target node
- Graceful fallback: if node path doesn't exist, warn but don't crash

### Tuning Pass

Play each game in arcade mode. Target: 15–45 seconds per game. Adjust overrides until pacing feels right. Additional overrides may be needed (ball speed, AI difficulty, spawn count).

### Deliverable

All 9 working games play fast and punchy in arcade mode. A full 3-life run takes 3–8 minutes. The pacing feels like a real arcade cabinet — rapid, intense, "one more go."

---

## Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| 0a | Add `start`, `coin`, `pause` to Input Map | — |
| 0b | Refactor `player_control.gd` to pure Input Map | 0a |
| 0c | Refactor `ugs._unhandled_input` to routed methods | 0a |
| 0d | Add UGS Mode enum (STANDALONE/ARCADE) | 0c |
| 1a | Create `Scripts/Hub/` and `Scenes/Hub/` directories | — |
| 1b | Create `arcade_game_entry.gd` resource | — |
| 1c | Create `arcade_orchestrator.gd` (state machine + game loading) | 0d, 1b |
| 1d | Create `boot_screen.tscn` (simple insert coin/press start) | 0a |
| 1e | Create `arcade_orchestrator.tscn` (scene assembly) | 1c, 1d |
| 1f | Test: boot → Pong loads → plays → ends → score read | all above |
| 2a | Create `arcade_playlist.gd` resource | 1b |
| 2b | Add lives system to orchestrator | 1c |
| 2c | Add game sequence + preload | 2a |
| 2d | Add scrolling transition | 2b |
| 2e | Add score carry + streak multiplier | 2b |
| 2f | Add simple Game Over screen | 2b |
| 2g | Test: full 3-life run through all games | all above |
| 3a | Create ArcadeGameEntry resources per game | 2a |
| 3b | Implement override application | 1b |
| 3c | Tuning pass: play and adjust overrides | 3a, 3b |
| 3d | Create `arcade_default_playlist.tres` | 3a |
| 3e | Final playtest: full run with fast rules | all above |

---

## Risks & Considerations

1. **Input refactoring scope** — Every game depends on `player_control.gd`. Changes here must be tested across all 9 games. Risk of regressions is high. Test incrementally.

2. **UGS `$Interface` coupling** — The `p1_win()`/`p1_lose()` methods directly call `$Interface.show_element()`. In ARCADE mode, the game scene may not have an Interface, or the Interface may show things the orchestrator doesn't want. The Mode enum must guard these calls.

3. **Property override paths** — Overrides use `NodePath` strings that reference the internal scene tree of each game. If a game's scene tree changes, the override breaks. The graceful fallback (warn, don't crash) is essential.

4. **Two games in tree during transition** — The scrolling transition briefly has two game instances in the tree. Memory and performance implications. Keep transition short (0.4s) and free old game promptly.

5. **Web audio context** — Browsers require user interaction to start AudioServer. The boot screen must handle this before any SoundSynth components try to play.

---

## Future Phases (Out of Scope)

- **Phase 4** — Polybius face + voice + dialogue
- **Phase 5** — Scoreboard with local high scores + initials entry
- **Phase 5.5** — Kill screen secret + code entry + Polybius whispers
- **Phase 6** — Juice: CRT effect, countdown, screen flash, transition sounds, ambient hum
- **Phase 7** — Ship: itch.io HTML5 export + browser testing