n# Plan 16 — Cambrian Remix Explosion

**Created:** 2026-05-06  
**Status:** Not started  
**Timeline:** Mid–late May (after Plans 14–15)  

---

## Goal

Three deliverables that turn the arcade mode into a shippable, replayable itch demo:

1. **10 remixes/originals** — 3 built, 3 designed below, 4 blank slots for future brainstorming
2. **5 modifiers** — A "taste" of the Balatro-like progression system, unlocked via cumulative score gates
3. **Semi-random playlist + persistence** — Structured game order + local high score saving

---

## The Game Roster

### Remakes (5/5 built)

| # | Game | Bootleg Name | Status |
|---|------|-------------|--------|
| 1 | Pong | Paddle Ball | ✅ Built |
| 2 | Breakout | Brick Breaker | ✅ Built |
| 3 | Asteroids | Space Rocks | ✅ Built |
| 4 | Space Invaders | Bug Blaster | ✅ Built |
| 5 | Tetris | Block Drop | ✅ Built |

### Remixes & Originals (3/10 built, 3 designed, 4 TBD)

| # | Game | Type | Status |
|---|------|------|--------|
| 1 | Dogfight | Original | ✅ Built |
| 2 | Meteor Rally | Remix (Paddle Ball + Space Rocks) | ✅ Built |
| 3 | Rock Breaker | Remix (Brick Breaker + Space Rocks) | ✅ Built |
| 4 | **Bug Drop** | Remix (Block Drop + Bug Blaster) | 📐 Designed below |
| 5 | **Space Bugs** | Remix (Bug Blaster + Space Rocks) | 📐 Designed below |
| 6 | **Planetary Attack!** | Remix (Bug Blaster reversed) | 📐 Designed below |
| 7 | *(TBD)* | — | 🔲 Blank |
| 8 | *(TBD)* | — | 🔲 Blank |
| 9 | *(TBD)* | — | 🔲 Blank |
| 10 | *(TBD)* | — | 🔲 Blank |

---

### New Game Designs

#### Bug Drop — Block Drop meets Bug Blaster

- Invaders march **upward** from the bottom (flipped upside-down)
- Player controls tetrominos, dropping them from the top
- **Scoring:** Complete "lines" using both Tetrominos and Invaders as fill — any complete row clears
- **Loss condition:** An invader reaches the top of the play field
- **Components:** SwarmController (reversed direction), TetrominoSpawner, LineClearMonitor, modified collision groups
- **Fast rules:** 2-3 rows of invaders, smaller play field, higher drop speed

#### Space Bugs — Bug Blaster meets Space Rocks

- Player controls a UFO (free-roaming, top-down like Space Rocks)
- Must contend with both **asteroids** (drifting, splitting) AND **invaders** (attacking from all sides, shooting)
- Two threat types simultaneously
- **Components:** player body (UFO/triangle ship), WaveSpawner for both asteroid and invader waves, SwarmController for invaders, gun_simple
- **Fast rules:** 1 wave of each, limited asteroid count

#### Planetary Attack! — Bug Blaster reversed

- Player controls **the invaders** — they march left/right, step down when reaching screen edges
- Goal: reach the bottom of the screen while avoiding cannon fire
- **Respawning cannons** (like the player in Bug Blaster) shoot upward at you
- **Protective barriers** block your path — must navigate around or through them
- **Loss:** All invaders destroyed before reaching the bottom
- **Components:** SwarmController (player controls the swarm direction), WaveSpawner for cannon defenses, barrier grid, GroupMonitor for invader count
- **Fast rules:** Fewer cannons, fewer barriers, wider step-down

---

## Semi-Random Playlist

The Arcade Orchestrator gets a new playlist mode:

### Structure

1. **Phase 1 (Warm-up):** 2 random games from the remakes list (5 choose 2 = 10 possible openings)
2. **Phase 2 (The Remix):** Random games from the remixes/originals list, no repeats until exhausted, then reshuffle
3. **No end** — Games continue until the player runs out of meta lives

### Implementation

- `ArcadePlaylist` gets a `mode` enum: `SEQUENTIAL`, `SHUFFLE`, `SEMI_RANDOM`
- `SEMI_RANDOM` mode: AO picks 2 random remakes first, then random remixes
- The AO already has playlist logic — this extends it with category awareness

---

## 5 Modifiers — The "Taste" of Progression

Pulled from the Contraband and Tokens categories in the balatro elements brainstorm. All 5 are **passive toggles** (contraband-style). The player turns them on/off on the title screen before starting a run. No consumable system yet — that's post-launch.

| # | Modifier | Category | Effect | Unlock Score |
|---|----------|----------|--------|-------------|
| 1 | **Double Barrel** | Token | `gun_simple` fires 2 bullets with slight spread | 100 |
| 2 | **Overclocked CPU** | Contraband | All `Leg` components: `speed` × 1.25 | 1,000 |
| 3 | **Feature Creep** | Token | All `spawner` components: `entity_count` × 2 | 10,000 |
| 4 | **Crunch Time** | Contraband | Lives set to 1. All score values × 3.0 | 100,000 |
| 5 | **Scope Creep** | Contraband | All `CollisionShape` radii × 1.20 (bigger hitboxes for everything) | 1,000,000 |

### Implementation

**Technical approach:** `ModifierManager` node spawned by the `ArcadeOrchestrator`. Connects to `SceneTree.node_added`. When a node enters the tree, checks active modifiers. If the node matches the target class/group, applies property overrides before the node's `_ready` finishes.

**New files:**

| File | Purpose |
|------|---------|
| `modifier_manager.gd` | Applies active modifier effects via GlobalPropertyOverride |
| `modifier_resource.gd` | Resource defining a modifier (name, description, unlock_score, overrides) |
| 5 × `.tres` modifier resources | Double Barrel, Overclocked CPU, Feature Creep, Crunch Time, Scope Creep |

**Modified files:**

| File | Changes |
|------|---------|
| `arcade_orchestrator.gd` | Spawn ModifierManager, pass active modifiers |
| Title screen / boot screen | UI for toggling unlocked modifiers on/off |

### Score Gate System

- Track `lifetime_score` across all runs (cumulative, persists)
- On boot, check which modifiers are unlocked: `lifetime_score >= modifier.unlock_score`
- Locked modifiers show as greyed out with their unlock threshold displayed
- Unlocked modifiers can be toggled freely — no limit on how many are active

---

## Local High Score Persistence

### How Godot Web Export Handles `user://`

- On web, `user://` maps to **IndexedDB** (the browser's structured storage)
- Data persists across sessions in the same browser
- Cleared if the user clears browser data or site data
- Works in Chrome, Firefox, Safari, Edge
- **No special code needed** — `FileAccess.open("user://...", FileAccess.WRITE)` works identically on web and desktop

### What Gets Saved

| File | Contents |
|------|----------|
| `user://arcade_highscores.json` | Top 10 high scores (initials + score + date) |
| `user://arcade_progress.json` | `lifetime_score` (for modifier unlocks) |

### Implementation

- Save on run end (scoreboard screen)
- Load on boot (title screen)
- Simple JSON via `JSON.stringify()` / `JSON.parse()`
- Already sketched in Plan 13 Phase 5

---

## Implementation Steps

| Step | What | Depends On |
|------|------|-----------|
| 1 | Build Bug Drop (remix scene + fast rules entry) | Plan 15 rename |
| 2 | Build Space Bugs (remix scene + fast rules entry) | Plan 15 rename |
| 3 | Build Planetary Attack! (remix scene + fast rules entry) | Plan 15 rename |
| 4 | Implement semi-random playlist mode in AO | — |
| 5 | Implement `modifier_manager.gd` + 5 modifier resources | — |
| 6 | Implement modifier toggle UI on title screen | Step 5 |
| 7 | Implement score gate system + `lifetime_score` tracking | — |
| 8 | Implement local high score save/load (JSON persistence) | — |
| 9 | Playtest all modifiers individually + in combinations | Steps 1–8 |
| 10 | Playtest semi-random playlist with 8+ games | Steps 1–4 |
| 11 | Fill remaining 4 remix slots (future brainstorming sessions) | — |

---

## Risks & Considerations

1. **Modifier balance** — 5 modifiers that can be combined freely = 32 possible combinations. Some combos will be broken (Double Barrel + Feature Creep = bullet hell). That's fine for a demo — it's the *point*. But playtesting should catch any combo that makes the game unplayable or crashes it.

2. **Scope Creep (the modifier)** — Increasing all hitbox sizes by 20% affects both player and enemy hitboxes. This means the player is also easier to hit. Need to playtest to make sure it doesn't make the game impossibly hard.

3. **Crunch Time** — Setting lives to 1 changes the meta-life system. The orchestrator needs to handle this override correctly — if Crunch Time is active, the player's meta lives should be 1 regardless of the playlist default.

4. **Feature Creep** — Doubling entity count could tank performance on web (itch.io). The 98-asteroid scenario. Should profile on a low-end machine before shipping.

5. **Bug Drop complexity** — This is the most mechanically complex of the 3 new games. Combining the Tetris grid system with invader AI is non-trivial. May need custom logic beyond pure component assembly.

6. **Planetary Attack! input** — Player controlling the invader swarm is a new input paradigm. Need to figure out: does the player step each invader individually? Or control the swarm as a group (like normal Space Invaders, but you're the invaders)? The design says "swarm as a group" — simpler to implement.

---

## What Doesn't Change

- **Component architecture** — New games are assemblies of existing components
- **Arcade Orchestrator core** — Playlist mode is additive, doesn't break existing sequential mode
- **Game scenes for existing games** — No modifications needed to support modifiers (that's the point of the GlobalPropertyOverride system)
- **Boot screen / Polybius** — Handled in Plan 15