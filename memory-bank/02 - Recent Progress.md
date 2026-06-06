# Recent Progress

**Last Updated:** 2026-06-05

---

## BB2 Session 2026-06-05b — Wasp & Spider Entities, Mixed Spawn Patterns, 5-Level Progression (0 new scripts, 6 new scenes, scene-driven)

Expanded Bug Blaster 2 from single-enemy-type to a 3-type ecosystem (bug/wasp/spider) with per-level mixed spawn ratios. All done through scene assembly — no new scripts required.

### New Entity Scenes (6)

| File | Purpose |
|------|---------|
| `entities/generic/wasp_ship.tscn` | Wasp generic entity (squid sprites) |
| `entities/generic/wasp_ship_smooth.tscn` | Wasp smooth variant |
| `entities/generic/spider_ship.tscn` | Spider generic entity (crab sprites) |
| `entities/generic/spider_ship_smooth.tscn` | Spider smooth variant |
| `entities/nonplayer/wasp_ship_swooping_nonplayer.tscn` | Wasp swooping nonplayer (AISwoopBrain + AnnouncerGuts) |
| `entities/nonplayer/spider_ship_swooping_nonplayer.tscn` | Spider swooping nonplayer (AISwoopBrain + AnnouncerGuts) |

### CDStageTrapdoor — `spawn_scenes` Array (modified)

Added `spawn_scenes: Array[PackedScene]` to the base class. When populated, `_get_spawn_scene()` cycles through the array by index (modulo length), falling back to `spawn_scene` for any remaining slots. This enables mixed-type spawning from a single trapdoor without subclassing.

**Before:** Single `spawn_scene` — all entities identical.
**After:** `spawn_scenes` array — each slot in the spawn queue can produce a different entity type.

### bug_blaster_2.tscn — 5-Level Mixed Spawn Progression

All 5 levels now produce exactly **32 bug + 16 wasp + 8 spider = 56 total** per level, using varied patterns:

| Level | TD1 (top_left, ×2 fires) | TD2 (top_right, ×2 fires) | TD3 (bottom_left, ×1) | TD4 (bottom_right, ×1) |
|-------|---------------------------|---------------------------|------------------------|-------------------------|
| 1 | 8 bug | 8 bug | 12 [S,W,W] | 12 [S,W,W] |
| 2 | 10 [B,B,B,W,W] | 10 [B,B,B,W,W] | 8 [B,S] | 8 [B,S] |
| 3 | 8 bug | 8 bug | 12 [S,W,W] | 12 [S,W,W] |
| 4 | 10 [B,B,B,W,W] | 8 [B,S] | 8 [B,S] | 10 [B,B,B,W,W] |
| 5 | 12 [S,W,W] | 12 [S,W,W] | 8 bug | 8 bug |

Each level also has unique swoop curves (helix, spiral, parabola, sine, circle, sequence), speeds (300–500), and SignalManager step sequences.

### Files

| File | Action |
|------|--------|
| `entities/generic/wasp_ship.tscn` | New |
| `entities/generic/wasp_ship_smooth.tscn` | New |
| `entities/generic/spider_ship.tscn` | New |
| `entities/generic/spider_ship_smooth.tscn` | New |
| `entities/nonplayer/wasp_ship_swooping_nonplayer.tscn` | New |
| `entities/nonplayer/spider_ship_swooping_nonplayer.tscn` | New |
| `games/bug_blaster_2.tscn` | Updated — 5 levels with mixed spawn patterns |
| `cd_stage_trapdoor.gd` | Modified — added `spawn_scenes` array |

### V2 Total Scripts Written: 170 (scene-driven, no new scripts)

---

## Plan 28 — V2 CDStage + CDBody (COMPLETE — 5 new scripts, 2 modified)

Sleep/wake container infrastructure + MANAGER category + data-driven stage/state/signal managers.

### Session 2 — Managers Layer (3 new scripts, 1 new resource, 2 modified)

Added MANAGER component category at priority 75 (between RULES 70 and UPDATE 90). Three new manager components + CDStageRule resource replace embedded control logic that was baked into CDStage.

| Feature | Implementation |
|---------|---------------|
| `MANAGER` category (priority 75) | New `CDEnums.ComponentCategory.MANAGER` — runs after RULES, before UPDATE |
| `CDStageRule extends Resource` | Trigger + sleep/wake stage names + game signals — replaces CDStage's `sleep_on`/`wake_on` |
| `StageManager extends CDGameComponent` | Evaluates CDStageRule triggers, sleeps/wakes named CDStages via lookup map |
| `StateManager extends CDGameComponent` | Renamed from StateDirector — same CDTransition logic, now at MANAGER priority |
| `SignalManager extends CDGameComponent` | Renamed from SignalSequenceDirector — data-driven timed signal sequences at MANAGER priority |
| CDStage simplified | Removed `sleep_on`/`wake_on` exports and signal handlers — StageManager handles this now |

### New Scripts (3 + 1 resource)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_stage_rule.gd` | `CDStageRule extends Resource` | Trigger → sleep/wake stages + game signals |
| `stage_manager.gd` | `StageManager extends CDGameComponent` | Evaluates CDStageRule triggers, sleeps/wakes named CDStages |
| `state_manager.gd` | `StateManager extends CDGameComponent` | Group-as-state transitions via CDTransition resources (renamed from StateDirector) |
| `signal_manager.gd` | `SignalManager extends CDGameComponent` | Timed signal macro sequences (renamed from SignalSequenceDirector) |

### Modified Scripts (2)

| Script | Changes |
|--------|---------|
| `cd_enums.gd` | Added `MANAGER` category at priority 75 |
| `cd_stage.gd` | Removed `sleep_on`/`wake_on` exports and signal handlers |

### Scenes (3 new)

| File | Purpose |
|------|---------|
| `scenes/game components/managers/stage_manager.tscn` | StageManager scene instance |
| `scenes/game components/managers/state_manager.tscn` | StateManager scene instance |
| `scenes/game components/managers/signal_manager.tscn` | SignalManager scene instance |

### BB2 Scene Updated

Removed `wake_on` from Level1Stage in `bug_blaster_2.tscn`. Editor rewire needed: add StageManager node with CDStageRules to replicate old wake-on-signal behavior.

### V2 Total Scripts Written: 170

---

### Session 1 — Sleep/Wake Containers (2 new scripts, 4 modified)

Sleep/wake container infrastructure for grouping components. CDStage manages game-level components (directors, trapdoors, goals, cards). CDBody manages entity-level components (brains, legs, arms, guts, faces, voices).

| Feature | Implementation |
|---------|---------------|
| `CDStage extends CDGameComponent` | Game-level container — collects child CDGameComponents, sleeps/wakes as a group |
| `CDBody extends CDEntityComponent` | Entity-level container — collects child CDEntityComponents, sleeps/wakes as a group |
| `_bus_connections` tracking | Both base classes now track bus connections via `self.bus_connect()`/`self.bus_disconnect()` |
| `_on_sleep()`/`_on_wake()` virtuals | Both base classes get overridable sleep/wake hooks (default: toggle physics process) |
| `CDEntity.set_subtree_collisions()` | Static helper to enable/disable collision shapes in direct children |
| `CDUpdater` sleep/wake queues | `_pending_sleep`/`_pending_wake` arrays, sleep-before-wake flush ordering |

### New Scripts (2)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_stage.gd` | `CDStage extends CDGameComponent` | Game-level sleep/wake container |
| `cd_body.gd` | `CDBody extends CDEntityComponent` | Entity-level sleep/wake container |

### Modified Scripts (4)

| Script | Changes |
|--------|---------|
| `cd_entity_component.gd` | Added `_bus_connections` array, `bus_connect()`/`bus_disconnect()` wrappers, `_on_sleep()`/`_on_wake()` virtuals |
| `cd_game_component.gd` | Same additions as above |
| `cd_entity.gd` | Added `set_subtree_collisions()` static, refactored `activate()` + `_complete_deactivation()` to use it |
| `cd_updater.gd` | Added `_pending_sleep`/`_pending_wake` queues, `queue_sleep()`/`queue_wake()` API, updated `_flush()` |

### Scenes (2 new)

| File | Purpose |
|------|---------|
| `scenes/core/infrastructure/cd_stage.tscn` | CDStage scene instance |
| `scenes/core/infrastructure/cd_body.tscn` | CDBody scene instance |

---

## Bug Blaster 2 — Session 2026-06-05: Starfield, Bug Fixes, CRT Diagnosis

Three bugs diagnosed and fixed during continued BB2 development.

### ScrollingStarsEffect — New Effect (1 new script)

Galaga-style scrolling star background for Bug Blaster 2.

| File | Action |
|------|--------|
| `scripts/effects/scrolling_stars_effect.gd` | New — `CDScrollingStarsEffect extends CDEffect` |
| `scenes/effects/scrolling_stars_effect.tscn` | New — scene instance |
| `games/bug_blaster_2.tscn` | Updated — added ScrollingStarsEffect (25 stars) |

**Exports:** `star_count`, `min_speed`, `max_speed`, `min_size`, `max_size`, `star_colors`, `effect_width`, `effect_height`
**Algorithm:** Random positions/speeds/colors, scrolls downward with wrap-around, renders via `_draw()` + `queue_redraw()`

### CDEffect — Infinite Lifetime Support

Modified `CDEffect` base class to support persistent (non-auto-freeing) effects:
- `lifetime = 0.0` now means "infinite" — no auto-free timer starts
- Enables scrolling backgrounds and other always-on visual effects

### SwoopDirector — Freed Instance Bug (Diagnosed)

**Bug:** `Trying to assign invalid previously freed instance` on line 211 (`var next: CDEntity = _pending.pop_front()`)

**Root cause:** Typed variable assignment of a freed instance crashes before `is_instance_valid()` can run. Entity killed by collision between frames, deferred `_complete_deactivation()` + `queue_free()` completes between frame N and frame N+1.

**Fix:** Remove `: CDEntity` type hint on `pop_front()` result, add `_pending` scrub to filter dead entities each frame.

### CRTProjector — Attract Mode Darkness Bug (Diagnosed + Fixed)

**Bug:** Screen appears darker during attract mode ("PRESS ENTER TO START") than during gameplay.

**Root cause:** `CDGame._ready()` sets all children to `PROCESS_MODE_PAUSABLE` and pauses the tree. CRTProjector never gets `_process()` called, so:
1. Shader params never pushed (CRT shader runs with GLSL defaults, no brightness/gamma/bloom)
2. Persistence buffer stays empty/black (CLEAR_MODE_NEVER but no frames rendered)

**Fix:** CRTProjector sets `process_mode = PROCESS_MODE_ALWAYS` in `_on_initialize()`, and pushes shader params immediately during initialization (not waiting for first `_process()`).

**V1 comparison:** V1 CRT controller is a child of ArcadeOrchestrator (PROCESS_MODE_ALWAYS), never affected by game pause. V2 parity restored.

### V2 Total Scripts Written: 166

---

## Documentation Sweep #2 — `ensure_signal` Removal + Directory Structure (COMPLETE)

Targeted audit fixing three systemic issues found in USAGE.md:

1. **`ensure_signal()` removed from all docs** — This function never existed in V2. `bus_connect()` auto-creates signals via `add_user_signal()`. All template code, step-by-step guides, and "Must-Includes" updated to remove the registration step. The 12-step component checklist became 11 steps.
2. **Validity guard examples updated** — Old pattern (`collider.emit_signal("take_damage", amount)`) replaced with blackboard pattern (`collider.blackboard["damage"] = amount; collider.bus_emit("take_damage")`) across §4 templates, §7 validity guards, and §6 anti-pattern examples.
3. **Directory structure updated** — memory-bank/01 now shows the actual nested subcategories (brains/player, brains/ai action, legs/directional setters, arms/collision reactions, etc.) instead of flat listings. Plan 28 added as "In Chamber".

### Files Updated

| File | Changes |
|------|---------|
| `USAGE.md` | Removed all `ensure_signal()` references. Updated all template code to blackboard pattern. Fixed validity guard examples. |
| `memory-bank/01` | Directory structure expanded to show nested subcategories. Plan 28 added. |

---

## Documentation Sweep #1 — All Docs Updated to Reflect V2 Architecture (COMPLETE)

Full documentation audit comparing all docs against actual codebase. Every file updated to reflect the current state of the V2 architecture, especially the blackboard signal system.

### What Changed

| File | Key Updates |
|------|------------|
| `USAGE.md` | §2 Signal Bus rewritten: game bus now correctly documented as native signals (not Dictionary). Added `bus_emit_from()`, `bus_connect()`, `bus_disconnect()` API tables. Blackboard data flow examples. Added auto-populated blackboard keys. Updated game bus signal table to show blackboard keys instead of typed args. §4 Brains: added PlayerMoveToBrain, PlayerKBMMoveBrain, AISwoopBrain; fixed AIAimBrain name. §4 Directors: replaced SwarmShootingDirector with ShootingDirector, AimingDirector, SignalSequenceDirector. §8 Resources: added Scalers (3), SequenceSteps, Formation (2), Visuals, CDGridRow. Appendix: updated all counts to 165 scripts + 46 resources. Fixed Brain template code to use `bus_connect`/`bus_emit` instead of `ensure_signal`/`connect`. Fixed Leg template code similarly. Fixed game bus example to show blackboard pattern. |
| `README` | Pipeline updated to include UPDATE(90). Signal Bus section rewritten: game bus now documented as native signals. Resource count updated 43→46. Component counts updated. Directors updated. |
| `memory-bank/01` | CDGame description updated. Signal system updated. Priority cascade fixed (added INPUT, AUDIO, UPDATE). V2 Architecture header changed from "In Progress" to "Complete". Directory structure updated to V2 layout with accurate counts. |
| `memory-bank/03` | Plan 27 status fixed from "docs in progress" to "Complete". Removed "documentation sweep" from post-Galaga tasks (done now). |
| `memory-bank/04` | V2 architecture section updated: both buses now documented as native signals + blackboard. Priority cascade fixed to include INPUT, AUDIO, UPDATE. Removed "documentation sweep" from remaining items. |
| `memory-bank/05` | Signal bus sections rewritten: entity bus now shows typed hardcoded signals + zero-arg dynamic signals with blackboard. Game bus now shows native signals (not Dictionary). |
| `memory-bank/07` | Overview updated to reflect native signals + blackboard for both buses. Priority cascade fixed. Visuals resource row added to count summary. |

### Key Corrections

1. **Game Bus was documented as "Dictionary-based"** — actual code uses `add_user_signal()` native Godot signals, same mechanism as entity bus
2. **Both buses use the same pattern:** native signals + blackboard Dictionary for data flow
3. **Old API references removed:** `bus_emit("signal", [args])` replaced with `bus_emit("signal")` + `blackboard["key"]`
4. **Template code updated:** `entity.ensure_signal()` + `entity.connect()` replaced with `entity.bus_connect()` pattern
5. **Stale component names fixed:** SwarmShootingDirector → ShootingDirector + AimingDirector, AIDiveBombBrain → AISwoopBrain, AIAimAtNearestBrain → AIAimBrain

---

## Plan 27 — V2 Blackboard Architecture (COMPLETE — 4 new scripts)

Architectural overhaul of V2 signal communication. The blackboard + `bus_emit()` architecture is now live in code. All user-defined signals are zero-arg, CDEntity and CDGame have `blackboard` dictionaries, and a per-frame `_signal_emitters` tracking system enables signal-aware selectors.

### What Was Implemented

| Feature | Implementation |
|---------|---------------|
| `entity.blackboard: Dictionary` | Transient state storage on every CDEntity |
| `game.blackboard: Dictionary` | Transient state storage on CDGame |
| `entity.bus_emit(signal_name)` | Zero-arg emission that auto-tracks emitter in `_signal_emitters` |
| `game.bus_emit(signal_name)` | Zero-arg emission on game bus |
| `game.bus_emit_from(signal_name, emitter)` | Tracks which entity emitted a signal this frame |
| `game._signal_emitters: Dictionary` | Per-frame registry cleared by CDUpdater at Priority 90 |
| `entity._signal_emitters: Dictionary` | Per-entity emitter registry for entity-bus signal tracking |
| CDUpdater flush | Clears `_signal_emitters` after all transitions processed |

### New Scripts (4)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_sequence_curve.gd` | `CDSequenceCurve extends CDCurve` | Chains multiple CDCurve resources into a single composite path |
| `cd_select_signal_emitter.gd` | `CDSelectSignalEmitter extends CDSelector` | Filters candidates to only those who emitted a specific signal this frame |
| `cd_select_nearest_n_to_group.gd` | `CDSelectNearestNToGroup extends CDSelector` | Selects N candidates nearest to closest entity in a target group |
| `player_kbm_move_brain.gd` | `PlayerKBMMoveBrain extends CDEntityComponent` | Unified KB+Mouse move brain — merges keyboard "move" and mouse "move_to" into single intent |

### Signal Emitter Pipeline (New)

The `bus_emit_from()` → `_signal_emitters` → `CDSelectSignalEmitter` pipeline enables "who signaled this frame?" queries:
1. Entity calls `bus_emit("swoop_complete")` or game calls `bus_emit_from("dive_complete", entity)`
2. Emitter is recorded in `_signal_emitters[signal_name]` array
3. CDSelectSignalEmitter cross-references candidates against the registry
4. CDUpdater clears `_signal_emitters` at end of frame (Priority 90)

### Remaining

- Migrate existing components from old `_arg1/_arg2` patterns to blackboard reads (ongoing, per-component)

### Files

| File | Action |
|------|--------|
| `planning/27 - V2 Blackboard Architecture.md` | Created — complete architecture spec |
| `cd_entity.gd` | Modified — added `blackboard`, `bus_emit()`, `_signal_emitters` |
| `cd_game.gd` | Modified — added `blackboard`, `bus_emit()`, `bus_emit_from()`, `_signal_emitters` |
| `cd_updater.gd` | Modified — clears `_signal_emitters` each frame |

### V2 Total Scripts Written: 165

---

## Polybius Character — COMPLETE (7 V1 scripts, 5 voice lines)

Plan 15 Phase 2 is fully implemented in V1. The Polybius character is a complete narrator/face for the arcade cabinet experience, with full ArcadeOrchestrator integration.

### What's Done

- **7 Polybius scripts:** `polybius_face.gd`, `polybius_eyes.gd`, `polybius_mouth.gd`, `polybius_nose.gd`, `polybius_beat.gd`, `polybius_line.gd`, `polybius_phrase.gd`
- **5 voice lines recorded:** `again.ogg`, `for_score.ogg`, `i_hunger.ogg`, `leaderboard.ogg`, `pathetic.ogg`
- **2 phrase resources:** `i_hunger.tres`, `leaderboard.tres`
- **Full AO integration:** `POLYBIUS` state in orchestrator state machine, intro plays before first game (`_show_polybius_screen("intro", ...)`), outro plays after final defeat (`_show_polybius_outro()`), SubViewport slide transitions between Polybius and games/game-over

### Files

| File | Purpose |
|------|---------|
| `v1/Scripts/Hub/polybius_face.gd` | Main Polybius face controller |
| `v1/Scripts/Hub/polybius_eyes.gd` | Eye drawing and animation |
| `v1/Scripts/Hub/polybius_mouth.gd` | Mouth drawing and animation |
| `v1/Scripts/Hub/polybius_nose.gd` | Nose drawing |
| `v1/Scripts/Hub/polybius_beat.gd` | Beat/timing system for phrase delivery |
| `v1/Scripts/Hub/polybius_line.gd` | Individual line delivery |
| `v1/Scripts/Hub/polybius_phrase.gd` | Phrase resource definition |
| `v1/Scenes/Hub/polybius_face.tscn` | Polybius face scene |
| `v1/Scenes/Hub/PolybiusPhrases/i_hunger.tres` | "I hunger" phrase |
| `v1/Scenes/Hub/PolybiusPhrases/leaderboard.tres` | "Leaderboard" phrase |
| `v1/Assets/Voice/again.ogg` | "Again" voice line |
| `v1/Assets/Voice/for_score.ogg` | "For score" voice line |
| `v1/Assets/Voice/i_hunger.ogg` | "I hunger" voice line |
| `v1/Assets/Voice/leaderboard.ogg` | "Leaderboard" voice line |
| `v1/Assets/Voice/pathetic.ogg` | "Pathetic" voice line |

---

## Bug Blaster 2 (Galaga) — Partial Implementation (0 new scripts, scene-driven)

Bug Blaster 2 is now a playable Galaga remake assembled entirely from existing V2 components. No new scripts were needed — the entire game is a scene assembly leveraging the V2 composable architecture.

### What's Working

- **Formation grid** — FormationDirector manages named slots, entities fill in via fill_direction priority
- **Swoop/dive attacks** — SwoopDirector selects entities from formation, StateDirector transitions them through formation→diving→returning groups, AISwoopBrain follows CDCurve paths with checkpoint-based movement
- **Shooting** — ShootingDirector (CDTimerTrigger + CDSelectRandomN) picks random enemies to fire, AimingDirector handles per-entity nearest-target aiming
- **Collision detection** — CDMark zones at bottom of screen detect dive-complete entities via `_on_body_entered`, emit `dive_complete` on game bus
- **StateDirector dive cycle** — CDSignalTrigger listens for `dive_complete` on game bus, CDTransition moves entities from `diving` to `returning` group, `return_to_formation` entity signal emitted
- **AISwoopBrain stop signals** — Added `stop_signals: Array[StringName]` (array-based exports), entity hears `return_to_formation` and aborts swoop early
- **Entity composition** — `bug_ship_swooping_nonplayer.tscn` with AISwoopBrain (CDSpiralCurve) + AnnouncerGuts (rebroadcasts `swoop_complete` to game bus)

### AISwoopBrain Refactor

Converted all signal exports from single StringName to arrays:
- `start_signal` → `start_signals: Array[StringName]`
- Added `stop_signals: Array[StringName]` — signals that abort the swoop early
- `move_signal` → `move_signals: Array[StringName]`
- `complete_signal` → `complete_signals: Array[StringName]`

### Remaining for Full Galaga

- Capture ships (bug ship variant with tractor beam)
- Capture mechanics (player gets captured → becomes dual fighter when rescued)
- Multiple waves with escalating patterns
- Bonus stages

### Files

| File | Action |
|------|--------|
| `scripts/entity components/brains/ai movement/ai_swoop_brain.gd` | Modified — array exports, stop_signals |
| `entities/nonplayer/bug_ship_swooping_nonplayer.tscn` | Updated — start_signals, stop_signals arrays |
| `games/remakes/bug_blaster_2.tscn` | Updated — full Galaga assembly |

### V2 Total Scripts Written: 156 (scene-driven implementation, before Plan 27 scripts)

---

## Plan 25 Post-Hoc — FormationDirector fill_direction + AISwoopBrain (1 new script, 1 modified)

### FormationDirector — Fill Direction Priority

Added `fill_direction: Vector2` export to FormationDirector. Rewrote `_find_empty_slot()` with priority scoring:
- `Vector2.ZERO` → center-out fill (closest to center first)
- Non-zero → directional fill (dot product scoring, e.g. `Vector2.RIGHT` fills right side first)

### AISwoopBrain — Entity-Level Curve Path Following

New brain: entity-level narrow-phase counterpart to SwoopDirector. Uses `CDCurve` resources for path generation, triggered on/off via entity bus signals (emitted by StateDirector). Direction + distance targeting instead of group targeting. One-shot path, emits `swoop_complete` when done.

| File | Action |
|------|--------|
| `formation_director.gd` | Modified — added fill_direction export, rewrote _find_empty_slot() |
| `ai_swoop_brain.gd` | New — CDCurve checkpoint path following brain |

### V2 Total Scripts Written: 156

---

## Plan 25 Post-Hoc — ShootingDirector + AimingDirector (2 new scripts)

Replaced the monolithic `SwarmShootingDirector` with two data-driven directors that plug into the existing CDTrigger/CDSelector resource system.

### New Directors (2 scripts)

| Script | Class | Summary |
|--------|-------|---------|
| `shooting_director.gd` | `ShootingDirector extends CDGameComponent` | Data-driven shooting: CDTrigger decides WHEN, CDSelector decides WHO |
| `aiming_director.gd` | `AimingDirector extends CDGameComponent` | Per-entity nearest-target aiming across groups with throttling and noise |

### Design

- **ShootingDirector**: Gathers candidates from `target_groups`, filters to valid/active, uses `CDSelector` to narrow the pool, emits `shoot` signal on each selected entity. Fully configurable via CDTimerTrigger + CDSelectRandomN for "every 2s, 1 random enemy shoots" patterns.
- **AimingDirector**: Each shooter independently finds its nearest target across `target_groups`. Supports `update_interval` for throttled recalculation and `targeting_noise` for imprecision. Pattern lifted from `AIAimAtNearestBrain` but elevated to a director controlling many entities at once.

### Files

| File | Action |
|------|--------|
| `scripts/game components/directors/shooting_director.gd` | New |
| `scripts/game components/directors/aiming_director.gd` | New |
| `scenes/game components/directors/shooting_director.tscn` | New |
| `scenes/game components/directors/aiming_director.tscn` | New |
| `games/remakes/bug_blaster_2.tscn` | Updated — replaced SwarmShootingDirector |

### V2 Total Scripts Written: 155

---

## Plan 25 — V2 Swarm Controllers + Galaga (COMPLETE — 0 new scripts)

Plan 25 required zero new scripts. All proposed components were already built during Plans 21–24 under different names, or deemed redundant with existing components. The plan document was rewritten as an architectural reference.

### Component Reconciliation

| Plan 25 Proposed | Actual Name | Built In | Status |
|---|---|---|---|
| CDSwarmStateMachine | StateDirector | Plan 24 | Renamed |
| SwoopController | SwoopDirector | Plan 24 | Renamed |
| FormationController | FormationDirector | Plan 24 | Renamed |
| SwarmShootingController | SwarmShootingDirector | Plan 24 | Renamed |
| CaptureMonitor | StageDirector | Plan 24 | Renamed |
| CDCaptureRule | CDDirectorRule | Plan 24 | Renamed |
| CDBusBridge | AnnouncerGuts | Plan 24 | Renamed |
| ShootIntervalBrain | AIRepeatActionBrain | Plan 21 | Renamed |
| TractorBeamBrain | AITractorBeamBrain | Plan 24 | Renamed |
| DiveBombBrain | AIDiveBombBrain | Plan 21 | Renamed |
| ReturnController | FormationDirector | Plan 24 | Redundant |
| FollowerAI | AIChaseBrain | Plan 21 | Redundant |
| CompanionOffsetGuts | AIFormationBrain | Plan 21 | Redundant |

### Key Deliverable
- Rewrote `planning/25 - V2 Swarm Controllers + Galaga.md` as complete architectural reference with Galaga lifecycle, signal flow, entity compositions, state machine configuration, and validation checklist
- Updated memory bank files (01, 02, 03) to reflect completion

---

## USAGE.md — Architecture Documentation (COMPLETE)

Created `USAGE.md` — the comprehensive guide to all patterns, anti-patterns, and code quality guidelines for the V2 composable architecture. Covers the priority pipeline, signal bus system, component lifecycle, per-category usage guides, core patterns, anti-patterns, code quality guidelines, and extension instructions.

Also created `memory-bank/05 - Patterns & Anti-Patterns.md` as a quick-reference index for AI agents, replacing the retired V1 Component Catalogue.

Updated `memory-bank/01 - Current Status.md` to streamline toward V2, removing V1-centric signal flow documentation and V1 component catalog.

---

## Plan 24 — V2 Faces, Voices, Projections & Speakers (COMPLETE)

Plan 24 is fully implemented. 63 new V2 scripts written — the largest single plan to date. Brings visual representation, entity audio, game-level audio, post-processing, AI path curves, state machine triggers, entity selectors, behavior resources, audio resources, effects, and new infrastructure online.

### Faces — Visual Representation (7 scripts)

| Script | Description |
|--------|-------------|
| `polygon_face.gd` | Draws filled polygons from CDShape resources |
| `vector_face.gd` | Draws polylines from CDShape resources |
| `menacing_vector_face.gd` | Vector face with CRT menace effects: glitch, static, glow, scan, corrupt |
| `sprite_face.gd` | Draws Texture2D, swaps texture based on signal-to-frame bindings |
| `death_effect_face.gd` | Spawns CDEffect scenes at entity position when it dies |
| `vector_engine_face.gd` | Main engine exhaust flame for Asteroids-style ship |
| `vector_thruster_face.gd` | Four vector engine flames in an X pattern |

### Voices — Entity Audio (2 scripts)

| Script | Description |
|--------|-------------|
| `sound_voice.gd` | One-shot or jingle triggered by entity bus signal |
| `continuous_voice.gd` | Ongoing sound tied to entity state |

### Speakers — Game-Level Audio (3 scripts)

| Script | Description |
|--------|-------------|
| `sound_speaker.gd` | Game-level one-shot or jingle triggered by game bus signal |
| `continuous_speaker.gd` | Game-level continuous sound |
| `music_speaker.gd` | Playlist + dual-player crossfade + loop-point logic |

### Projectors — Visual Post-Processing (2 scripts)

| Script | Description |
|--------|-------------|
| `crt_projector.gd` | CRT post-processing pipeline for V2 |
| `credit_projection.gd` | Floating credit overlay showing track title and artist |

### Directors — Stage-Level Controllers (5 scripts)

| Script | Description |
|--------|-------------|
| `stage_director.gd` | Listens for game bus signals, performs entity swaps |
| `state_director.gd` | Updates entity groups for group-as-state management |
| `formation_director.gd` | Manages a grid of named slots for formation entities |
| `swarm_shooting_director.gd` | Periodically selects entities from target groups to shoot |
| `swoop_director.gd` | Generates curve from CDCurve resource, moves entities along it |

### Effects (2 scripts)

| Script | Description |
|--------|-------------|
| `broken_ship_effect.gd` | Spinning line fragments that drift outward and fade |
| `death_particle_effect.gd` | Burst of single-pixel particles that fly outward |

### Resources — Curves (12 scripts)

Abstract base `CDCurve` plus 11 curve types for AI path generation: arc, circle, helix, lissajous, parabola, sawtooth wave, sine, spiral, square wave, triangle, zigzag.

### Resources — Triggers (5 scripts)

Abstract base `CDTrigger` plus 4 trigger types: composite (AND/OR), group_count, signal, timer.

### Resources — Selectors (5 scripts)

Abstract base `CDSelector` plus 4 selection strategies: all, first N, nearest N, random N.

### Resources — Behavior (4 scripts)

| Script | Description |
|--------|-------------|
| `cd_director_rule.gd` | Defines one entity swap rule for StageDirector |
| `cd_shape.gd` | Defines a polygon shape from a set of 2D points |
| `cd_transition.gd` | Defines when and how entities move between groups |
| `cd_wall_kick.gd` | Wall-kick offset table data for Tetris-style rotation |

### Resources — Audio (3 scripts)

| Script | Description |
|--------|-------------|
| `cd_music_track.gd` | Defines a single music track for MusicSpeaker playlists |
| `cd_note.gd` | Note definition for synthesized audio |
| `cd_sound_def.gd` | Sound definition resource |

### Resources — Visuals (1 script)

| Script | Description |
|--------|-------------|
| `cd_face_binding.gd` | Pairs a signal name and frame index for face components |

### New Infrastructure (3 scripts)

| Script | Description |
|--------|-------------|
| `cd_effect.gd` | Lightweight visual effect base — plays once and auto-frees |
| `cd_sound_bank.gd` | Centralized audio engine for V2 (CDGameComponent-based) |
| `cd_updater.gd` | Defers state updates (component and group changes) to end of frame |

### Additional Brains (3 scripts)

| Script | Description |
|--------|-------------|
| `ai_tractor_beam_brain.gd` | Interrupts dive to perform capture attempt |
| `player_move_to_brain.gd` | Emits "move_to" with mouse global position each physics frame |

### Additional Guts (4 scripts)

| Script | Description |
|--------|-------------|
| `announcer_guts.gd` | Listens for entity bus signals, rebroadcasts on game bus |
| `kbm_guts.gd` | Merges keyboard "move" and mouse "move_to" into single "steer" signal |
| `move_adapter_guts.gd` | Converts "move_to" target positions into "move" direction vectors |
| `timer_guts.gd` | Emits tick and expired signals on a timer |

### Additional Arms (3 scripts)

| Script | Description |
|--------|-------------|
| `powerup_delivery_arm.gd` | Delivers a powerup to whatever entity collides with |
| `powerup_wingman_arm.gd` | Spawns companion entity at player position on powerup received |
| `tractor_beam_arm.gd` | Active-frames arm that captures entities in tractor beam zone |

### V2 Total Scripts Written: 153

---

## Plan 23 — V2 Spawners (COMPLETE)

Plan 23 is fully implemented. 14 new V2 scripts written across Trapdoors, Spawn Arms, Marks, and Resources. All stage-level and entity-level spawning is in place.

### Trapdoors — Stage-Level Spawners (4 scripts)

| Script | Description |
|--------|-------------|
| `cd_stage_trapdoor.gd` | Abstract base class — trigger→queue→stagger→spawn lifecycle, telefrag, pool, safe zone |
| `point_trapdoor.gd` | Spawns at own position with random offset (UFOs, power-ups, bosses) |
| `edge_trapdoor.gd` | Distributes spawns along selected screen edges with jitter |
| `grid_trapdoor.gd` | 2D grid spawning — data-driven (CDGridLayout) or math-driven (CDGridEquation) with skip filtering |

### Spawn Arms — Entity-Level Spawners (3 scripts)

| Script | Description |
|--------|-------------|
| `gun_arm.gd` | Spawns projectile on fire signal, pool-backed with cooldown and rotation inheritance |
| `spawn_on_death_arm.gd` | Spawns entities when parent entity dies (death effects, asteroid splits, power-up drops) |
| `piece_splitter_arm.gd` | Tetris-specific — spawns SettledCell entities at piece block positions, then deactivates parent |

### Marks — Spawn Support (2 scripts)

| Script | Description |
|--------|-------------|
| `safe_zone_mark.gd` | Spawn-safety monitor — emits `zone_safe`/`zone_unsafe` on game bus |
| `occupancy_mark.gd` | Occupancy tracker — emits `occupancy_changed` with group name and count on game bus |

### Resources — Spawn Data (4 scripts)

| Script | Description |
|--------|-------------|
| `cd_spawn_context.gd` | Lightweight resource for configuring spawned entities (velocity, random angle, flips, rotation) |
| `cd_grid_layout.gd` | Data-driven grid definition — explicit PackedScene per cell, null = skip |
| `cd_grid_equation.gd` | Math-driven grid definition — uniform scene with randomized skips |
| `cd_utilities.gd` | Pure static utilities — `apply_spawn_context()` and `evaluate_int()` (Expression-based equation evaluator) |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Renamed CDStageSpawner → CDStageTrapdoor | Evocative name that disambiguates from entity-level GunArm/SpawnOnDeathArm. Trapdoors are on the floor (stage), spilling enemies upward. |
| CDStageTrapdoor is non-virtual base, not abstract | No GDScript abstract keyword. Uses non-virtual pattern — base class is fully functional, subclasses override `_generate_positions()` to add positioning logic. |
| Trigger→Queue→Stagger→Spawn lifecycle | Decouples wave signal arrival from actual spawning. Queue batch-collects, stagger spaces them visually, spawn is the final step. |
| CDGridLayout for data-driven, CDGridEquation for math-driven | Two grid strategies cover all use cases. GridTrapdoor uses strategy pattern to select at runtime. |
| CDUtilities.evaluate_int() for equation strings | Godot's Expression class evaluates math strings like "8 - floor(x / 4)". Enables designer-editable spawn counts without code changes. |
| SafeZoneMark as signal-driven Area2D | Replaces V1's polling `_wait_for_safe_zone` coroutine. Emits on game bus — trapdoor subscribes, no coupling. |
| Telefrag respects health pipeline | Damages entity first (via `take_damage` signal on entity bus), lets HealthPoolGuts/ShieldPoolGuts process, entity's own death logic handles cascade. |

### V2 Total Scripts Written: 90

---

## Plan 22 — V2 Arms + Guts (COMPLETE)

Plan 22 is fully implemented. 24 new V2 scripts written across Arms and Guts categories. All collision response, internal state tracking, resource pools, status effects, and Tetris-specific detectors are in place.

### Arms (10 scripts)

**Collision Response Arms (6):**

| Script | Description |
|--------|-------------|
| `damage_on_hit_arm.gd` | Emits `take_damage` on collider's bus when this entity is the instigator |
| `death_on_hit_arm.gd` | Emits `request_deactivate` on collider's bus when this entity is the instigator |
| `damage_on_crash_arm.gd` | Emits `take_damage` on collider's bus for any collision (mutual damage) |
| `death_on_crash_arm.gd` | Emits `request_deactivate` on collider's bus for any collision (mutual destruction) |
| `damage_on_joust_arm.gd` | Emits `take_damage` on the slower collider's bus (velocity comparison) |
| `death_on_joust_arm.gd` | Emits `request_deactivate` on the slower collider's bus (velocity comparison) |

**Scoring Arms (2):**

| Script | Description |
|--------|-------------|
| `score_on_collision_arm.gd` | Emits `add_score` on game bus when collision occurs with target groups |
| `score_on_death_arm.gd` | Emits `add_score` on game bus when this entity deactivates |

**Force & Status Arms (2):**

| Script | Description |
|--------|-------------|
| `pushback_arm.gd` | Emits `external_impulse` on collider's bus based on collision normal |
| `status_on_hit_arm.gd` | Emits `apply_status` on collider's bus with configurable status and duration |

### Guts (13 new scripts)

**Collision & Shape (2):**

| Script | Description |
|--------|-------------|
| `deflector_bounce_guts.gd` | Bounces entity velocity on collision using configurable response mode |
| `shape_collider_guts.gd` | Manages collision shape enable/disable for pooled entities |

**Health & Death (2 new + 1 existing):**

| Script | Description |
|--------|-------------|
| `healthpool_guts.gd` | Tracks HP with configurable damage/heal, emits `health_changed` and `health_depleted` |
| `die_at_zero_health_guts.gd` | Listens for `health_depleted` and calls `entity.deactivate()` |
| `points_guts.gd` | Holds point value for scoring (pre-existing, confirmed compatible) |

**Self-Destruction (3):**

| Script | Description |
|--------|-------------|
| `die_on_timer_guts.gd` | Destroys entity after configurable lifespan |
| `die_out_of_bounds_guts.gd` | Polling bounds check against `game.game_bounds` with spawn delay |
| `die_offscreen_guts.gd` | Camera-visibility cleanup via `VisibleOnScreenNotifier2D` (event-driven) |

**Force Reception (1):**

| Script | Description |
|--------|-------------|
| `impulse_receiver_guts.gd` | Listens for `external_impulse` and passes it to the velocity accumulator |

**Resource Pools (2):**

| Script | Description |
|--------|-------------|
| `shieldpool_guts.gd` | Rechargeable buffer on top of HealthPool — absorbs damage, overflows remainder |
| `resourcepool_guts.gd` | Generic spendable pool (stamina/mana/ammo) with regeneration |

**Status Effects (1):**

| Script | Description |
|--------|-------------|
| `stun_guts.gd` | Disables Brains and Legs for a duration, emits `status_began`/`status_ended` |

**Grid / Tetris (2):**

| Script | Description |
|--------|-------------|
| `lock_detector_guts.gd` | Detects when grid piece can't fall, manages lock delay with infinite-spin prevention |
| `t_spin_detector_guts.gd` | SRS 3-corner rule T-Spin detection with full/mini classification |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| DieOffscreenGuts split | Two variants: polling (OutOfBounds, game_bounds) vs event-driven (Offscreen, camera visibility). Different use cases for bullets vs enemies. |
| ShieldPool damage pipeline | ShieldPool emits overflow to `take_health_damage` (different signal than `take_damage`), avoiding tree-ordering issues with HealthPool. Both fire synchronously via Godot signals. |
| LockDetectorGuts uses `step_blocked` | Grid pieces use position teleportation, not physics collision. LockDetector listens to `step_blocked(direction)` from GridMovementLeg instead of `collision`. |
| TSpinDetectorGuts rotation tracking | Tracks `_rotation_state` (0-3) and checks which specific corners are filled to distinguish full T-Spin from mini. |
| ResourcePoolGuts spend-fail signal | Emits `resource_spend_failed` instead of returning bool (Godot signals can't capture return values). |

### V2 Total Scripts Written: 76

---

## Plans 19.5, 20, 21 — V2 Object Pooling, Stage, Brains + Legs (COMPLETE)

Plans 19 through 21 are now fully implemented. 42 new V2 scripts written across object pooling, stage components, and the complete entity component catalog.

### Plan 19.5 — V2 Object Pooling

| Script | Description |
|--------|-------------|
| `cd_object_pool.gd` | Per-type entity pool with acquire/return lifecycle |

### Plan 20 — V2 Stage (10 scripts)

**Cue Cards (4):**

| Script | Description |
|--------|-------------|
| `score_card.gd` | Tracks score with optional multiplier |
| `lives_card.gd` | Tracks player lives |
| `timer_card.gd` | Tracks time and emits signals |
| `wave_card.gd` | Tracks current wave number; signal relay for spawners |

**Goals (2):**

| Script | Description |
|--------|-------------|
| `group_count_goal.gd` | Triggers when group counts match a condition |
| `score_threshold_goal.gd` | Triggers when score crosses a threshold |

**Marks (4):**

| Script | Description |
|--------|-------------|
| `cd_mark.gd` | Emits signals on body entered and exited |
| `count_mark.gd` | Emits after N unique bodies have entered |
| `mobile_mark.gd` | Mark that follows a target CDEntity with lock-on |
| `timed_mark.gd` | Emits while a body remains inside the zone for a duration |

### Plan 21 — V2 Brains + Legs (29 scripts + 1 resource)

**Player Brains (3):**

| Script | Description |
|--------|-------------|
| `player_move_brain.gd` | Routes directional input from CDInputRouter to entity bus |
| `player_aim_brain.gd` | Routes aim input from CDInputRouter to entity bus |
| `player_action_brain.gd` | Routes action button presses/releases from CDInputRouter to entity bus |

**AI Brains (10):**

| Script | Description |
|--------|-------------|
| `ai_chase_brain.gd` | Emits movement direction towards nearest target |
| `ai_flee_brain.gd` | Emits movement direction away from nearest target |
| `ai_aim_brain.gd` | Emits aim direction towards nearest target |
| `ai_orbit_brain.gd` | Emits movement direction orbiting a CDEntity |
| `ai_repeat_action_brain.gd` | Fires action signal repeatedly on timer |
| `ai_timed_step_brain.gd` | Emits directional signal at regular interval |
| `ai_path_move_brain.gd` | Follows Curve2D resource as waypoints |
| `ai_random_sweep_brain.gd` | Generates multi-waypoint sweep path |
| `ai_idle_wander_brain.gd` | Picks random nearby points, meanders with idles |
| `ai_formation_brain.gd` | Moves to offset from leader entity |
| `ai_dive_bomb_brain.gd` | Generates sine-wave dive path toward target |

**Legs (15):**

| Script | Description |
|--------|-------------|
| `direct_movement_leg.gd` | Hard-sets velocity from directional input |
| `acceleration_movement_leg.gd` | Accelerates toward input direction |
| `engine_leg.gd` | Forward velocity based on facing direction |
| `linear_friction_leg.gd` | Linearly scaling friction |
| `static_friction_leg.gd` | Constant deceleration to zero |
| `boomerang_leg.gd` | Constant return force toward spawn position |
| `direct_rotation_leg.gd` | Tank-style continuous rotation |
| `target_rotation_leg.gd` | Rotates toward aim direction |
| `grid_movement_leg.gd` | Fixed grid step if target cell unoccupied |
| `grid_rotation_leg.gd` | Tetris-style rotation with wall-kick tables |
| `grid_drop_leg.gd` | Drops entity by N grid cells |
| `grid_alignment_leg.gd` | Ensures entity stays snapped to pseudo-grid |
| `direct_target_leg.gd` | Constant speed toward world-space target |
| `acceleration_target_leg.gd` | Accelerates toward target, tapers on approach |
| `screen_wrap_leg.gd` | Wraps entity to opposite side when out of bounds |

**Guts (1):**

| Script | Description |
|--------|-------------|
| `vision_cone_guts.gd` | Forward-facing vision cone that detects bodies |

**Resources (1):**

| Script | Description |
|--------|-------------|
| `wall_kick_resource.gd` | Wall-kick offset table data for Tetris-style rotation |

### V2 Total Scripts Written: 52

---

## Plan 19 — V2 Core Infrastructure (COMPLETE)

All 10 V2 core scripts written and in place at `Godot/scripts/core/`. Foundation of the V2 Composable Architecture is live.

### Scripts Written

| Script | Class | Type | Lines | Summary |
|--------|-------|------|-------|---------|
| `cdenums.gd` | `CDEnums` | Data bag | ~80 | Shared enums: ComponentCategory, EntityState, GameState, GameResult, CollisionResponse, CountComparison, Edge, InputAction |
| `cdcollisiongroup.gd` | `CDCollisionGroup extends Resource` | Resource | ~15 | Named collision group with `collides_with` targets |
| `cdentitycomponent.gd` | `CDComponent2D extends Node2D` | Base class | ~30 | Entity component base. Two-phase lifecycle, cached entity+game refs, priority by category |
| `cdgamecomponent.gd` | `CDStageComponent2D extends Node2D` | Base class | ~27 | Game-stage component base. Same lifecycle but no entity ref. For CDGame children |
| `cdentity.gd` | `CDEntity extends CharacterBody2D` | Entity | ~160 | Velocity accumulator, entity bus, state machine (ACTIVE→DEACTIVATING→INACTIVE), collision shape API, buffered collisions |
| `cdcollisionbuffer.gd` | `CDCollisionBuffer extends Node` | Infrastructure | 16 | Deferred collision flush at Priority 35 |
| `cdgroupregistry.gd` | `CDGroupRegistry extends Node` | Infrastructure | 76 | Frame-cached typed group queries, dirty-flag pattern, `group_count_changed` signal, spatial queries |
| `cdcollisionmatrix.gd` | `CDCollisionMatrix extends Node` | Infrastructure | 44 | Auto-configures physics layers from CDCollisionGroup resources. 32-layer fail-fast |
| `cdgame.gd` | `CDGame extends Node2D` | Game root | 114 | Game bus (Dictionary), state machine (ATTRACT→PLAYING→GAME_OVER), signal-based input connection, clean state transitions |
| `cdinputrouter.gd` | `CDInputRouter extends Node` | Autoload | 65 | Pure signal emitter. Per-player move/aim/action signals. System buttons (start/restart/quit/pause). Bespoke action names |

### Key Design Decisions (during implementation)

| Decision | Rationale |
|----------|-----------|
| Clean state transitions on CDGame | Removed `_on_start_pressed`/`_on_restart_pressed`/`_on_quit_pressed` wrappers. `start_game()` IS the response. No double-guarding. |
| Signal-based CDGame↔CDInputRouter | CDGame connects to router signals in `_ready()`. ArcadeOrchestrator mediates in arcade mode. Router never imports CDGame. |
| Bespoke action names for Input Map | `fire`, `thrust`, `rotate_cw` etc. instead of generic `button_r`. Enables future remapping via Godot's InputMap API with zero router changes. |
| Component naming | `CDComponent2D` (entity children) and `CDStageComponent2D` (CDGame children) — separate base classes, no null checks for entity on game components |

### Files Created

| File | Purpose |
|------|---------|
| `Godot/scripts/core/cdenums.gd` | Shared enumerations |
| `Godot/scripts/core/cdcollisiongroup.gd` | Collision group resource |
| `Godot/scripts/core/cdentitycomponent.gd` | Entity component base (CDComponent2D) |
| `Godot/scripts/core/cdgamecomponent.gd` | Game-stage component base (CDStageComponent2D) |
| `Godot/scripts/core/cdentity.gd` | Base entity |
| `Godot/scripts/core/cdcollisionbuffer.gd` | Deferred collision flush |
| `Godot/scripts/core/cdgroupregistry.gd` | Cached group queries |
| `Godot/scripts/core/cdcollisionmatrix.gd` | Physics layer config |
| `Godot/scripts/core/cdgame.gd` | Game root with bus |
| `Godot/scripts/core/cdinputrouter.gd` | Input routing autoload |

---

## V2 Architecture Planning (COMPLETE)

All 8 V2 planning documents are complete, audited, and ready for implementation. The canonical design reference is `planning/V2 Rules.md`.

### Planning Cleanup (May 23)
- V1 planning docs (Plans 00–18) archived to `planning/v1/`
- V2 Rules document created at `planning/V2 Rules.md` — canonical reference for all V2 architectural decisions, patterns, and conventions
- Memory bank updated to reflect V2 architecture as the active priority

### Complete V2 Planning Docs (8 plans + 1 rules doc)
| Doc | Status |
|-----|--------|
| `planning/V2 Rules.md` | **Canonical reference** — all patterns, rules, conventions |
| `planning/19 - V2 Core Infrastructure.md` | Complete ✓ Audited |
| `planning/19.5 - V2 Object Pooling.md` | Complete ✓ Audited |
| `planning/20 - V2 Stage.md` | Complete ✓ Audited |
| `planning/21 - V2 Brains + Legs.md` | Complete ✓ Audited |
| `planning/22 - V2 Arms + Guts.md` | Complete ✓ Audited |
| `planning/23 - V2 Spawners.md` | Complete ✓ Audited |
| `planning/24 - V2 Faces, Voices, Projections & Speakers.md` | Complete ✓ Audited |
| `planning/25 - V2 Swarm Controllers + Galaga.md` | Complete ✓ Audited |
| `planning/26 - Block Drop V2.md` | Complete ✓ Audited |

### V2 Architecture at a Glance

See `planning/V2 Rules.md` for the full canonical reference. Key decisions:

- **Deterministic priority cascade:** Registry(5) → Brains(10) → Legs(20) → Entity(30) → Buffer(35) → Arms(40) → Guts(50) → Faces(60) → Stage(70)
- **Hybrid bus system:** Entity bus (native signals, typed, high-frequency) + Game bus (Dictionary-based, configurable names, zero boilerplate)
- **Velocity accumulator:** Legs submit requests, CDEntity resolves at Priority 30
- **Two-phase lifecycle:** `_ready()` for registration, `_on_initialize()` (deferred) for signal connections
- **Signal-driven purity:** Components never call methods on other components — only emit signals
- **On Hit / On Crash pattern:** Clean 2×2 matrix for collision response (DamageOnHit, DeathOnHit, DamageOnCrash, DeathOnCrash)
- **Group-as-State:** Entity group membership IS entity state. CDGroupRegistry is single source of truth.
- **Pseudogrid pattern:** Physics IS the grid. No grid data structures.
- **Object pooling:** Pool reference IS the toggle. Entity routes itself. Separate acquire and activate.
- **V1 preservation:** V1 moves to `Godot/v1/`. V2 at `Godot/` root. Itch demo stays on V1.

---