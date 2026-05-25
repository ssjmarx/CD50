# Recent Progress

**Last Updated:** 2026-05-24

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