# Plan: Componentized Hub — Reusable Game Infrastructure

## Goal

Create reusable components for game scripts to eliminate repetitive "glue" code. Instead of writing "wait for players to die, then show game over" 50 times, we build autonomous components that handle state management, scoring, and transitions.

---

## Philosophy: The "Flow Machine" Architecture

The `Universal_Game_Script` should not just be a data container—it should be a **State Machine** that coordinates autonomous Rule, Manager, and Flow components.

**Core Principle:** Game scripts configure components, components drive the game logic.

---

## Core: Universal_Game_Script

**Purpose:** State machine base class for all game coordinators.

### States
- `IDLE` (Attract Mode)
- `PLAYING`
- `PAUSED`
- `GAME_OVER`

### Responsibilities
- Receives `player_dead`, `enemies_cleared`, `objective_cleared` signals from Rule components
- Handles transition logic (e.g., if `PLAYING` and `player_dead` received → switch to `GAME_OVER`)
- Emits global signals: `on_game_start`, `on_game_end`, `on_score_changed`, `game_over(final_score)`
- Automatically instances configurable `ScoreUI` scene
- **Auto-instantiates CollisionMatrix for automatic body configuration**

### Required API for Future Hub Integration
1. **Signal `game_over(final_score: int)`** — Future hub scripts connect to this; game does not handle scene reset itself
2. **Method `start_game()`** — External caller (eventually hub) calls this to begin gameplay; triggers countdown and player spawn
3. **Export `game_title: String`** — For future UI systems to display game name

---

## Rules: Autonomous Game Logic Components

These components use **Godot Groups** to monitor game state. Bodies add themselves to groups (e.g., `"player"`, `"enemy"`, `"target"`), and Rule components scan for these groups.

### Objective_Monitor (formerly Player_Monitor and Enemy_Life_Monitor)
TRACKS CONFIGURABLE LOGICAL GROUP, SCANS TREE FOR GROUP MEMBERS DURING PHYSICS PROCESS, REPORTS WHEN GROUP IS EMPTY

### Lives_Counter
COUNTS LIVES, CONFIGURES MAX LIVES, RESETS LIVES WHEN SIGNALED, CHANGES LIVES WHEN SIGNALED, SIGNALS WHEN LIVES ARE ZERO

### Timer_Rule
CREATES A TIMER, STARTS TIMING WHEN SIGNALED, CALLS A SIGNAL FROM THE PARENT WHEN THE TIME IS UP
---

## Managers: Meta-Game Infrastructure

These handle "meta" logic of the scene so game scripts don't need to implement it.

### Collision_Matrix (Built into Universal_Game_Script)

**Problem:** Setting collision layers in editor for 50 games is tedious and error-prone.

**Solution:** Built into `Universal_Game_Script` base class, auto-configures physics for all bodies.

**Implementation:**
- Collision Matrix is auto-instantiated in `Universal_Game_Script._ready()`
- Accessible via `collision_matrix` property on all game scripts
- Listens to `child_entered_tree` and `child_exiting_tree` signals
- Automatically configures any UniversalBody added to game scene (dynamic spawns handled)

**Logic:**
- On `_ready()`, scans all existing UniversalBody children in scene
- Listens to `child_entered_tree` to auto-configure dynamically spawned bodies
- Automatically sets `collision_layer` and `collision_mask` based on `collision_groups` export
- Uses string-to-bitmask mapping (e.g., "player" → layer 1, "enemy" → layer 2)
- Bodies also auto-add to Godot groups for Rule component scanning

**Configuration Example:**
The game script configures collision groups with a simple dictionary:
- `"player"` collides with `"enemy"` and `"enemy_bullet"`
- `"player_bullet"` collides with `"enemy"`
- `"enemy"` collides with `"player"`

**Velocity Gain:**
- **Zero setup:** Collision Matrix exists automatically in every game
- **One-liner configuration:** Just call `collision_matrix.setup({...})` in game script
- **Dynamic spawns handled:** Any `add_child(UniversalBody)` triggers auto-configuration
- **Dual purpose:** Configures physics layers AND registers Godot groups for Rule components

---

## Flow: Bridging Rules and Game Script

These components connect Rule components to Game Script state changes.

### Wave_Director
- **Logic:** Connects to `Objective_Monitor.objective_cleared`
- **Behavior:**
  - When `objective_cleared` fires, waits configurable delay (e.g., 2 seconds)
  - Calls `Spawner.spawn_next_wave()`
  - Updates "Level X" UI element
- **Exports:** `wave_delay: float = 2.0`, `max_waves: int = -1` (infinite)
- **Use Case:** Galaga, Space Invaders, Centipede

**Removes need to write:** "Level progression" code for every shooter game.

### Intermission_Screen
- **Logic:** Listens for Game Script state changes via signals
- **Behavior:**
  - On `GAME_OVER`: Spawns "Game Over" sprite + "Insert Coin" text
  - On `IDLE`: Spawns "Title Screen"
  - On `VICTORY`: Spawns "You Win" screen
- **Exports:** `game_over_scene: PackedScene`, `title_scene: PackedScene`, `victory_scene: PackedScene`
- **Use Case:** All arcade games

**Removes need to write:** UI code in game scripts; just drop this node in.

---

## Juice: Polish Components

### Screen_Shake & Hit_Stop (Autoloads/Singletons)
**Why:** You don't want to `$ScreenShake.shake()` from deep inside a bullet script. You want `ScreenShake.shake()` globally.

**Logic:**
- `ScreenShake.shake(intensity: float, duration: float)`
- `HitStop.stop(duration: float)` — Freezes all physics/game logic for X seconds
- When Game Script receives `player_died` signal, it calls `HitStop.stop(0.1)`

### Explosion
- **Refinement:** Inherits from `UniversalBody` so it can use `Collision_Matrix` if needed (e.g., Missile Command explosions kill enemies)
- **Logic:** Auto-plays animation, auto-queues free when complete
- **Signals:** `animation_finished`

---

## The "Composition" in Action: Example Galaga

With componentized architecture, game script becomes incredibly sparse:

**Galaga.gd Overview:**
- Extends Universal_Game_Script base class
- Export: `game_title: String = "GALAGA"` for Orchestrator UI

**_ready() Initialization:**
- Calls `collision_matrix.setup({...})` with collision group dictionary:
  - `"player"` collides with `"enemy"` and `"enemy_bullet"`
  - `"player_bullet"` collides with `"enemy"`
  - `"enemy"` collides with `"player"`
- Connects Objective_Monitor `victory` signal to `_on_level_clear` method
- Connects Player_Monitor `defeat` signal to `_on_game_over` method
- Calls `start_game()` method (inherited from Universal_Game_Script)

**_on_level_clear() Handler:**
- Empty method placeholder
- Wave Director automatically handles wave spawning when objective_cleared fires

**_on_game_over() Handler:**
- Calls `emit_signal("game_over", $ScoreUI.score)` 
- Passes final score to Orchestrator
- Intermission_Screen component automatically shows "Game Over" UI

**Result:**
All heavy lifting (spawning waves, counting lives, showing UI) is handled by components. The game script just configures them.

---

## Component Checklist

To implement this plan, create the following components:

### Core
- [ ] `Universal_Game_Script.gd` — Base class with state machine, signal routing, UI instancing

### Rules
- [ ] `Player_Monitor.gd` — Scans "player" group, emits player_died/defeat
- [ ] `Objective_Monitor.gd` — Scans "enemy"/"target"/"brick" groups, emits objective_cleared/victory
- [ ] `Lives_Counter.gd` — Tracks lives, emits lives_changed/lives_depleted
- [ ] `Timer_Rule.gd` — Counts up/down, emits timer_tick/timer_expired

### Managers
- [ ] `Collision_Matrix.gd` — Auto-configures collision layers from dictionary (built into Universal_Game_Script)

### Flow
- [ ] `Wave_Director.gd` — Connects to Objective_Monitor, spawns waves
- [ ] `Intermission_Screen.gd` — Shows title/game over/victory screens based on state

### Hub
- [ ] `Arcade_Orchestrator.gd` — Manages game lifecycle
- [ ] `Scroller.gd` — Visual transition component
- [ ] `Score_Attack.gd` — Tracks session score
- [ ] `Time_Attack.gd` — Tracks completion time
- [ ] `Playlist.gd` — Defines game order

### Juice (Autoloads)
- [ ] `ScreenShake.gd` — Singleton for screen shake effects
- [ ] `HitStop.gd` — Singleton for freeze-frame impact

---

## Migration Strategy

### Phase 1: Core & Rules (Foundational)
1. Create `Universal_Game_Script` base class
2. Build Rule components (Player_Monitor, Objective_Monitor, Lives_Counter, Timer_Rule)
3. Test with a simple game (e.g., Pong refactored to use components)

### Phase 2: Managers & Flow (Infrastructure)
1. Create `Collision_Matrix` (built into Universal_Game_Script)
2. Create `Wave_Director`, `Intermission_Screen`
3. Refactor Asteroids to use Wave Director

### Phase 3: Juice & Polish (Visual Impact)
1. Create `ScreenShake`, `HitStop` autoloads
2. Refactor Explosion component to inherit UniversalBody
3. Add CRT shader integration
4. Full integration test across all 4 games

### Phase 4: Hub Components (Future - When Ready)
1. Create `Arcade_Orchestrator`, `Scroller`, `Playlist`
2. Create `Score_Attack`, `Time_Attack`
3. Build basic Hub scene with various mode compositions
4. See `planning/brainstorming/arcade_orchestrator_design.md` for details

### Phase 5: Legacy Migration (Backfill)
1. Refactor Pong to use componentized architecture
2. Refactor Breakout to use componentized architecture
3. Verify all games follow the same `game_over` signal pattern
4. Update memory-bank with new component inventory

---

## Risks & Considerations

1. **Godot Groups:** Must ensure all Bodies add themselves to appropriate groups on spawn. Consider adding a helper method to `UniversalBody.gd` for automatic group registration based on exports.

2. **Signal Bloat:** Universal_Game_Script exposes many signals. Must document clearly which components emit which signals.

3. **State Complexity:** State machine needs careful design. What happens if `objective_cleared` and `player_died` fire in the same frame? Priority rules must be defined.

4. **Performance:** High-frequency spawning in bullet-hell games requires optimization strategies. Test with many simultaneous objects to ensure smooth framerates.

5. **Loading Hiccups:** Deferred loading of next game during current game play is essential for seamless transitions. Test on lower-end hardware.

6. **Backward Compatibility:** Existing game scripts (pong.gd, breakout.gd, etc.) must be refactored to inherit from `Universal_Game_Script`. Consider a migration path that allows gradual adoption.

---

## Success Criteria

- [ ] All Rule components are autonomous (no game script babysitting)
- [ ] `Collision_Matrix` reduces physics setup to one line of code
- [ ] Game scripts are <50 lines of configuration code (vs 200+ lines of logic)
- [ ] Component composition allows easy game creation and modification
- [ ] Universal_Game_Script provides consistent game lifecycle API
