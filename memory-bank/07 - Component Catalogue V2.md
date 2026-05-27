# Component Catalogue V2

**Last Updated:** 2026-05-26  
**Architecture:** V2 Composable Architecture  
**Canonical Reference:** `planning/V2 Rules.md`  

---

## Overview

The V2 architecture replaces V1's `UniversalBody`/`UniversalComponent` system with `CDEntity`/`CDEntityComponent`/`CDGameComponent`. Components communicate via entity bus (native signals) and game bus (Dictionary). Processing order is deterministic via priority categories.

**Priority Cascade:** Registry(5) → Brains(10) → Legs(20) → Entity(30) → Buffer(35) → Arms(40) → Guts(50) → Faces(60) → Stage(70)

---

## Core — Base Classes (3)

| Script | Class | Description |
|--------|-------|-------------|
| `cd_cue_card.gd` | `CDCueCard` | Base class for all cue cards (extends Control instead of Node2D) |
| `cd_entity_component.gd` | `CDEntityComponent` | Base class for all V2 entity-attached components |
| `cd_game_component.gd` | `CDStageComponent2D` | Base class for all V2 game-attached components |

---

## Core — Infrastructure (7)

| Script | Class | Description |
|--------|-------|-------------|
| `cd_entity.gd` | `CDEntity` | Base class for all V2 physical entities |
| `cd_game.gd` | `CDGame` | Root node for every game scene — state machine and signal router |
| `cd_input_router.gd` | `CDInputRouter` | Autoloaded pure signal-driven input handler |
| `cd_group_registry.gd` | `CDGroupRegistry` | Frame-cached, typed access to entity groups |
| `cd_collision_buffer.gd` | `CDCollisionBuffer` | Flushes collisions after all movement is complete |
| `cd_collision_matrix.gd` | `CDCollisionMatrix` | Auto-configures physics layers from CDCollisionGroup resources |
| `cd_object_pool.gd` | `CDObjectPool` | Per-type entity pool |

---

## Core — Resources (3)

| Script | Class | Description |
|--------|-------|-------------|
| `cd_enums.gd` | `CDEnums` | Data bag for common enums across the codebase |
| `cd_collision_group.gd` | `CDCollisionGroup` | Resource used by CDCollisionMatrix to configure collision layers |
| `wall_kick_resource.gd` | `WallKickResource` | Wall-kick offset table data for Tetris-style rotation (8 kick arrays: 0→R, R→0, R→2, 2→R, 2→L, L→2, L→0, 0→L) |

---

## Entity Components — Brains (14)

Pure intent generators (Priority 10). Never touch velocity, never move entities. Emit signals on the entity bus.

### Player Brains (3)

| Script | Class | Description |
|--------|-------|-------------|
| `player_move_brain.gd` | `PlayerMoveBrain` | Routes directional input from CDInputRouter to entity bus |
| `player_aim_brain.gd` | `PlayerAimBrain` | Routes aim input from CDInputRouter to entity bus |
| `player_action_brain.gd` | `PlayerActionBrain` | Routes action button presses/releases from CDInputRouter to entity bus |

### AI: Targeting Brains (4)

| Script | Class | Description |
|--------|-------|-------------|
| `ai_chase_brain.gd` | `AIChaseBrain` | Emits movement direction towards the nearest thing in target groups |
| `ai_flee_brain.gd` | `AIFleeBrain` | Emits movement direction away from the nearest thing in target groups |
| `ai_aim_brain.gd` | `AIAimBrain` | Emits aim direction towards the nearest thing in target groups |
| `ai_orbit_brain.gd` | `AIOrbitBrain` | Emits movement direction orbiting a CDEntity with lock-on behavior |

### AI: Action Brains (2)

| Script | Class | Description |
|--------|-------|-------------|
| `ai_repeat_action_brain.gd` | `AIRepeatActionBrain` | Fires an action signal repeatedly on a timer while active; started and stopped by signal |
| `ai_timed_step_brain.gd` | `AITimedStepBrain` | Emits a directional signal at a regular interval; listens on the entity bus for speed-up |

### AI: Path & Patrol Brains (4)

| Script | Class | Description |
|--------|-------|-------------|
| `ai_path_move_brain.gd` | `AIPathMoveBrain` | Follows a pre-defined Curve2D resource, emitting positional targets as waypoints |
| `ai_random_sweep_brain.gd` | `AIRandomSweepBrain` | Generates a multi-waypoint sweep path across the play area |
| `ai_idle_wander_brain.gd` | `AIIdleWanderBrain` | Picks random nearby points and meanders toward them with idles in between |
| `ai_formation_brain.gd` | `AIFormationBrain` | Moves to an offset from a leader entity with target locking |
| `ai_dive_bomb_brain.gd` | `AIDiveBombBrain` | On signal, generates a sine-wave dive path toward a target |

---

## Entity Components — Arms (10)

World-affecting components (Priority 40). Consume collision signals from the buffer flush and affect other entities or the game state.

### Collision Response Arms (6)

On Hit / On Crash matrix — the 2×2 pattern for entity destruction and damage.

| Script | Class | Description |
|--------|-------|-------------|
| `damage_on_hit_arm.gd` | `DamageOnHitArm` | Emits `take_damage` on collider's bus when this entity is the instigator in a hit |
| `death_on_hit_arm.gd` | `DeathOnHitArm` | Emits `request_deactivate` on collider's bus when this entity is the instigator in a hit |
| `damage_on_crash_arm.gd` | `DamageOnCrashArm` | Emits `take_damage` on collider's bus for any collision (mutual damage) |
| `death_on_crash_arm.gd` | `DeathOnCrashArm` | Emits `request_deactivate` on collider's bus for any collision (mutual destruction) |
| `damage_on_joust_arm.gd` | `DamageOnJoustArm` | Emits `take_damage` on the slower collider's bus (velocity comparison) |
| `death_on_joust_arm.gd` | `DeathOnJoustArm` | Emits `request_deactivate` on the slower collider's bus (velocity comparison) |

### Scoring Arms (2)

| Script | Class | Description |
|--------|-------|-------------|
| `score_on_collision_arm.gd` | `ScoreOnCollisionArm` | Emits `add_score` on game bus when collision occurs with target groups |
| `score_on_death_arm.gd` | `ScoreOnDeathArm` | Emits `add_score` on game bus when this entity deactivates |

### Force & Status Arms (2)

| Script | Class | Description |
|--------|-------|-------------|
| `pushback_arm.gd` | `PushbackArm` | Emits `external_impulse` on collider's bus based on collision normal |
| `status_on_hit_arm.gd` | `StatusOnHitArm` | Emits `apply_status` on collider's bus with configurable status name and duration |

---

## Entity Components — Guts (15)

Internal state trackers (Priority 50). No world interaction — hold entity state and emit signals when state changes.

### Collision & Shape (2)

| Script | Class | Description |
|--------|-------|-------------|
| `deflector_bounce_guts.gd` | `DeflectorBounceGuts` | Bounces entity velocity on collision using configurable response mode |
| `shape_collider_guts.gd` | `ShapeColliderGuts` | Manages collision shape enable/disable (needed for pooled entities) |

### Health & Death (3)

| Script | Class | Description |
|--------|-------|-------------|
| `healthpool_guts.gd` | `HealthPoolGuts` | Tracks HP with configurable damage/heal, emits `health_changed` and `health_depleted` |
| `die_at_zero_health_guts.gd` | `DieAtZeroHealthGuts` | Listens for `health_depleted` and calls `entity.deactivate()` |
| `points_guts.gd` | `PointsGuts` | Holds point value for scoring — data holder consumed by ScoreOnDeathArm |

### Self-Destruction (3)

| Script | Class | Description |
|--------|-------|-------------|
| `die_on_timer_guts.gd` | `DieOnTimerGuts` | Destroys entity after a configurable lifespan (bullets, bombs) |
| `die_out_of_bounds_guts.gd` | `DieOutOfBoundsGuts` | Polling-based bounds check against `game.game_bounds` with spawn delay |
| `die_offscreen_guts.gd` | `DieOffscreenGuts` | Camera-visibility-based cleanup via `VisibleOnScreenNotifier2D` (event-driven) |

### Force Reception (1)

| Script | Class | Description |
|--------|-------|-------------|
| `impulse_receiver_guts.gd` | `ImpulseReceiverGuts` | Listens for `external_impulse` and passes it to the velocity accumulator |

### Resource Pools (2)

| Script | Class | Description |
|--------|-------|-------------|
| `shieldpool_guts.gd` | `ShieldPoolGuts` | Rechargeable buffer on top of HealthPool — absorbs damage, overflows remainder |
| `resourcepool_guts.gd` | `ResourcePoolGuts` | Generic spendable pool (stamina/mana/ammo) with regeneration and spend-fail signal |

### Status Effects (1)

| Script | Class | Description |
|--------|-------|-------------|
| `stun_guts.gd` | `StunGuts` | Disables Brains and Legs for a duration, emits `status_began`/`status_ended` |

### Grid / Tetris (2)

| Script | Class | Description |
|--------|-------|-------------|
| `lock_detector_guts.gd` | `LockDetectorGuts` | Detects when a grid piece can't fall further, manages lock delay with infinite-spin prevention |
| `t_spin_detector_guts.gd` | `TSpinDetectorGuts` | SRS 3-corner rule T-Spin detection with full/mini classification, announces to game bus |

### Vision (1)

| Script | Class | Description |
|--------|-------|-------------|
| `vision_cone_guts.gd` | `VisionConeGuts` | Forward-facing vision cone that detects bodies |

---

## Entity Components — Legs (15)

Movement executors (Priority 20). Consume entity bus signals and submit velocity/position requests. Never generate intent.

### Continuous Physics Legs (6)

Velocity-based movement using the accumulator API.

| Script | Class | Description | API |
|--------|-------|-------------|-----|
| `direct_movement_leg.gd` | `DirectMovementLeg` | Hard-sets velocity from a directional input signal | `velocity_set` |
| `acceleration_movement_leg.gd` | `AccelerationMovementLeg` | Accelerates toward an input direction | `velocity_add` |
| `engine_leg.gd` | `EngineLeg` | Adds forward velocity based on entity facing direction (Asteroids-style) | `velocity_add` |
| `linear_friction_leg.gd` | `LinearFrictionLeg` | Linearly scaling friction from 0 to top speed | `velocity_add` |
| `static_friction_leg.gd` | `StaticFrictionLeg` | Constant deceleration until velocity reaches zero | `velocity_add` |
| `boomerang_leg.gd` | `BoomerangLeg` | Applies a constant return force toward spawn position | `velocity_add` |

### Rotation Legs (2)

| Script | Class | Description | API |
|--------|-------|-------------|-----|
| `direct_rotation_leg.gd` | `DirectRotationLeg` | Tank-style continuous rotation from directional input and/or action signals | rotation |
| `target_rotation_leg.gd` | `TargetRotationLeg` | Rotates toward an aim direction | rotation |

### Grid Legs (4)

Discrete instant displacement using the position API.

| Script | Class | Description | API |
|--------|-------|-------------|-----|
| `grid_movement_leg.gd` | `GridMovementLeg` | Moves entity by a fixed grid step if target cell is unoccupied | `position_add` |
| `grid_rotation_leg.gd` | `GridRotationLeg` | Tetris-style rotation with wall-kick offset tables | rotation + `position_add` |
| `grid_drop_leg.gd` | `GridDropLeg` | Drops entity by N grid cells; used for line clear settling | `position_add` |
| `grid_alignment_leg.gd` | `GridAlignmentLeg` | Ensures entity stays snapped to a pseudo-grid | `position_set` |

### Position-Targeting Legs (2)

Consume positional signals (`move_to(Vector2)`) — the positional analog of directional legs.

| Script | Class | Description | API |
|--------|-------|-------------|-----|
| `direct_target_leg.gd` | `DirectTargetLeg` | Moves at a constant speed toward a world-space target position | `velocity_set` |
| `acceleration_target_leg.gd` | `AccelerationTargetLeg` | Accelerates toward a world-space target position, tapers based on distance | `velocity_add` |

### Spatial Utility Legs (1)

| Script | Class | Description | API |
|--------|-------|-------------|-----|
| `screen_wrap_leg.gd` | `ScreenWrapLeg` | Wraps entity to opposite side of screen when out of bounds | `position_set` |

---

## Game Components — Cue Cards (4)

Stage-level components (Priority 70) that display game state. Extend CDCueCard (Control-based).

| Script | Class | Description |
|--------|-------|-------------|
| `score_card.gd` | `ScoreCard` | Tracks score with optional multiplier |
| `lives_card.gd` | `LivesCard` | Tracks player lives |
| `timer_card.gd` | `TimerCard` | Tracks time and emits signals |
| `wave_card.gd` | `WaveCard` | Tracks current wave number and acts as a signal relay for spawners |

---

## Game Components — Goals (2)

Stage-level components that trigger game-end conditions.

| Script | Class | Description |
|--------|-------|-------------|
| `group_count_goal.gd` | `GroupCountGoal` | Triggers when group counts match a condition |
| `score_threshold_goal.gd` | `ScoreThresholdGoal` | Triggers when score crosses a threshold |

---

## Game Components — Marks (4)

Stage-level spatial detectors. Area2D-based triggers that emit signals on body contact.

| Script | Class | Description |
|--------|-------|-------------|
| `cd_mark.gd` | `CDMark` | Emits signals on body entered and exited |
| `count_mark.gd` | `CountMark` | Emits after N unique bodies have entered |
| `mobile_mark.gd` | `MobileMark` | Mark that follows a target CDEntity with lock-on behavior |
| `timed_mark.gd` | `TimedMark` | Emits while a body remains inside the zone for a configured duration |

---

## Component Count Summary

| Category | Count | Status |
|----------|-------|--------|
| Core Base Classes | 3 | Complete |
| Core Infrastructure | 7 | Complete |
| Core Resources | 3 | Complete |
| Brains | 14 | Complete |
| Arms | 10 | Complete |
| Guts | 15 | Complete |
| Legs | 15 | Complete |
| Cue Cards | 4 | Complete |
| Goals | 2 | Complete |
| Marks | 4 | Complete |
| **Total V2 Scripts** | **76** | |

---

## Not Yet Implemented (Planned)

These categories are planned but not yet written:

| Category | Plan | Expected Components |
|----------|------|---------------------|
| Spawners | Plan 23 | CDStageSpawner, PointSpawner, EdgeSpawner, GridSpawner, etc. |
| Faces | Plan 24 | CDFace, CDFaceBinding, etc. |
| Voices | Plan 24 | CDVoice, CDSpeaker, CDSoundBank, etc. |
| Stage Controllers | Plan 25 | SwarmGridStep, Formation, Flock, Shoot controllers |

---

## V1 → V2 Name Migration

| V1 Script | V2 Script(s) | Notes |
|-----------|-------------|-------|
| `player_control.gd` | `player_move_brain.gd` + `player_aim_brain.gd` + `player_action_brain.gd` | Split into 3 single-concern brains |
| `interceptor_ai.gd` | `ai_chase_brain.gd` + `ai_aim_brain.gd` | Monolith split into targeting brains |
| `aim_ai.gd` | `ai_aim_brain.gd` | Direct migration |
| `clear_shot_ai.gd` | `ai_repeat_action_brain.gd` + `vision_cone_guts.gd` | Vision cone + repeated action |
| `cover_ai.gd` | `ai_flee_brain.gd` + `ai_path_move_brain.gd` | Flee + patrol hybrid split |
| `falling_ai.gd` | `ai_random_sweep_brain.gd` | 3-phase sweep pattern |
| `patrol_ai.gd` | `ai_path_move_brain.gd` | Now uses Curve2D resources |
| `shoot_ai.gd` | `ai_repeat_action_brain.gd` + `vision_cone_guts.gd` | Vision cone + repeated action |
| `direct_movement.gd` | `direct_movement_leg.gd` | Now uses velocity accumulator |
| `direct_acceleration.gd` | `acceleration_movement_leg.gd` | Now uses velocity accumulator |
| `engine_simple.gd` / `engine_complex.gd` | `engine_leg.gd` + `direct_rotation_leg.gd` | Combined engine split |
| `friction_linear.gd` | `linear_friction_leg.gd` | Direct migration |
| `friction_static.gd` | `static_friction_leg.gd` | Direct migration |
| `grid_movement.gd` | `grid_movement_leg.gd` | Direct migration |
| `grid_rotation.gd` + `grid_rotation_advanced.gd` | `grid_rotation_leg.gd` | Merged — wall-kick via WallKickResource |
| `grid_gravity.gd` | `ai_timed_step_brain.gd` + `grid_drop_leg.gd` | Brain + Leg split |
| `rotation_direct.gd` | `direct_rotation_leg.gd` | Direct migration |
| `rotation_target.gd` | `target_rotation_leg.gd` | Direct migration |
| `warp_asteroids.gd` | `screen_wrap_leg.gd` | Direct migration |
| *(new)* | `direct_target_leg.gd` | Positional targeting leg (no V1 equivalent) |
| *(new)* | `acceleration_target_leg.gd` | Positional targeting leg (no V1 equivalent) |
| *(new)* | `grid_alignment_leg.gd` | Grid snap + drift correction (no V1 equivalent) |
| *(new)* | `boomerang_leg.gd` | Return-force leg (no V1 equivalent) |