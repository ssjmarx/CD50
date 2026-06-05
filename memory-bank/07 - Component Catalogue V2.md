# Component Catalogue V2

**Last Updated:** 2026-06-04  
**Architecture:** V2 Composable Architecture  
**Canonical Reference:** `planning/V2 Rules.md`  
**Total V2 Scripts:** 165

---

## Overview

The V2 architecture replaces V1's `UniversalBody`/`UniversalComponent` system with `CDEntity`/`CDEntityComponent`/`CDGameComponent`. Components communicate via entity bus and game bus (both native Godot signals + blackboard). All dynamic signals are zero-arg; data flows through `entity.blackboard` and `game.blackboard`. Processing order is deterministic via priority categories.

**Priority Cascade:** Registry(5) → Input(8) → Brains(10) → Legs(20) → Entity(30) → Buffer(35) → Arms(40) → Guts(50) → Faces(60) → Voices(65) → Stage(70) → Update(90)

---

## Core — Base Classes (4)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_cue_card.gd` | `CDCueCard extends Control` | Base class for all cue cards (Control-based, not Node2D) |
| `cd_entity_component.gd` | `CDEntityComponent extends Node2D` | Base class for all V2 entity-attached components |
| `cd_game_component.gd` | `CDGameComponent extends Node2D` | Base class for all V2 game-attached components |
| `cd_stage_trapdoor.gd` | `CDStageTrapdoor extends CDGameComponent` | Base class for all stage trapdoors |

---

## Core — Infrastructure (10)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_collision_buffer.gd` | `CDCollisionBuffer extends Node` | Flushes collisions after all movement is complete |
| `cd_collision_matrix.gd` | `CDCollisionMatrix extends Node` | Auto-configures physics layers from CDCollisionGroup resources |
| `cd_effect.gd` | `CDEffect extends Node2D` | Lightweight visual effect — plays once and auto-frees |
| `cd_entity.gd` | `CDEntity extends CharacterBody2D` | Base class for all V2 physical entities |
| `cd_game.gd` | `CDGame extends Node2D` | Root node for every game scene — state machine and signal router |
| `cd_group_registry.gd` | `CDGroupRegistry extends Node` | Frame-cached, typed access to entity groups |
| `cd_input_router.gd` | `CDInputRouter extends Node` | Autoloaded pure signal-driven input handler |
| `cd_object_pool.gd` | `CDObjectPool extends Node` | Per-type entity pool |
| `cd_sound_bank.gd` | `CDSoundBank extends CDGameComponent` | Centralized audio engine for V2 |
| `cd_updater.gd` | `CDUpdater extends Node` | Defers state updates (component and group changes) to end of frame |

---

## Core — Resources: Infrastructure (3)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_collision_group.gd` | `CDCollisionGroup extends Resource` | Collision group config used by CDCollisionMatrix |
| `cd_enums.gd` | `CDEnums` | Shared enumerations across the codebase |
| `cd_utilities.gd` | `CDUtilities` | Pure static utility functions used across V2 |

---

## Core — Resources: Audio (3)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_music_track.gd` | `CDMusicTrack extends Resource` | Defines a single music track for MusicSpeaker playlists |
| `cd_note.gd` | `CDNote extends Resource` | Note definition for synthesized audio |
| `cd_sound_def.gd` | `CDSoundDef extends Resource` | Sound definition resource |

---

## Core — Resources: Behavior (8)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_director_rule.gd` | `CDDirectorRule extends Resource` | Defines one entity swap rule for StageDirector |
| `cd_shape.gd` | `CDShape extends Resource` | Defines a polygon shape from a set of 2D points |
| `cd_transition.gd` | `CDTransition extends Resource` | Defines when and how entities move between groups |
| `cd_wall_kick.gd` | `CDWallKick extends Resource` | Wall-kick offset table data for Tetris-style rotation |
| `cd_scaler.gd` | `CDScaler extends Resource` | Abstract base for float value scaling with game lifecycle |
| `cd_wave_scaler.gd` | `CDWaveScaler extends CDScaler` | Scales a value based on current wave number |
| `cd_group_count_scaler.gd` | `CDGroupCountScaler extends CDScaler` | Scales a value based on group population (ratio or linear) |
| `cd_sequence_step.gd` | `CDSequenceStep extends Resource` | Single step in a SignalSequenceDirector's timed signal sequence |

---

## Core — Resources: Curves (13)

Abstract base `CDCurve` plus 12 curve types for AI path generation.

| Script | Class | Summary |
|--------|-------|---------|
| `cd_curve.gd` | `CDCurve extends Resource` | Abstract base class for all path curve resources |
| `cd_arc_curve.gd` | `CDArcCurve extends CDCurve` | Arc/semicircle curve |
| `cd_circle_curve.gd` | `CDCircleCurve extends CDCurve` | Circle/ellipse curve |
| `cd_helix_curve.gd` | `CDHelixCurve extends CDCurve` | Helix/corkscrew curve |
| `cd_lissajous_curve.gd` | `CDLissajousCurve extends CDCurve` | Lissajous curve |
| `cd_parabola_curve.gd` | `CDParabolaCurve extends CDCurve` | Parabolic curve |
| `cd_sawtooth_wave_curve.gd` | `CDSawtoothWaveCurve extends CDCurve` | Sawtooth wave curve |
| `cd_sine_curve.gd` | `CDSineCurve extends CDCurve` | Sine wave curve |
| `cd_spiral_curve.gd` | `CDSpiralCurve extends CDCurve` | Spiral curve |
| `cd_square_wave_curve.gd` | `CDSquareWaveCurve extends CDCurve` | Square wave curve |
| `cd_triangle_curve.gd` | `CDTriangleCurve extends CDCurve` | Triangle "curve" |
| `cd_zigzag_curve.gd` | `CDZigzagCurve extends CDCurve` | Zigzag curve |
| `cd_sequence_curve.gd` | `CDSequenceCurve extends CDCurve` | Chains multiple CDCurve resources into a single composite path |

---

## Core — Resources: Selectors (7)

Abstract base `CDSelector` plus 6 selection strategies for transition targeting.

| Script | Class | Summary |
|--------|-------|---------|
| `cd_selector.gd` | `CDSelector extends Resource` | Abstract base class for transition entity selectors |
| `cd_select_all.gd` | `CDSelectAll extends CDSelector` | Selects every candidate — no filtering |
| `cd_select_n.gd` | `CDSelectN extends CDSelector` | Selects the first N candidates in iteration order |
| `cd_select_nearest_n.gd` | `CDSelectNearestN extends CDSelector` | Selects N candidates nearest to source position |
| `cd_select_nearest_n_to_group.gd` | `CDSelectNearestNToGroup extends CDSelector` | Selects N candidates nearest to closest entity in a target group |
| `cd_select_random_n.gd` | `CDSelectRandomN extends CDSelector` | Selects N random candidates, independently each evaluation |
| `cd_select_signal_emitter.gd` | `CDSelectSignalEmitter extends CDSelector` | Filters candidates to only those who emitted a specific signal this frame |

---

## Core — Resources: Spawners (4)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_grid_equation.gd` | `CDGridEquation extends Resource` | Math-driven grid definition |
| `cd_grid_layout.gd` | `CDGridLayout extends Resource` | Data-driven grid definition |
| `cd_grid_row.gd` | `CDGridRow extends Resource` | One row of a CDGridLayout grid |
| `cd_spawn_context.gd` | `CDSpawnContext extends Resource` | Configuration for spawned entities when they enter the tree |

---

## Core — Resources: Triggers (5)

Abstract base `CDTrigger` plus 4 trigger types for state machine transitions.

| Script | Class | Summary |
|--------|-------|---------|
| `cd_trigger.gd` | `CDTrigger extends Resource` | Abstract base class for all state machine transition triggers |
| `cd_composite_trigger.gd` | `CDCompositeTrigger extends CDTrigger` | Combines multiple sub-triggers with AND/OR logic |
| `cd_group_count_trigger.gd` | `CDGroupCountTrigger extends CDTrigger` | Checks group population against a threshold |
| `cd_signal_trigger.gd` | `CDSignalTrigger extends CDTrigger` | Fires when a game bus signal is received |
| `cd_timer_trigger.gd` | `CDTimerTrigger extends CDTrigger` | Fires on a configurable timer interval |

---

## Core — Resources: Formation (2)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_formation.gd` | `CDFormation extends Resource` | Sub-formation grid with preferred group, offset, and slot management |
| `cd_marching_order.gd` | `CDMarchingOrder extends Resource` | Formation movement command — step, breathe, or pause |

---

## Core — Resources: Visuals (1)

| Script | Class | Summary |
|--------|-------|---------|
| `cd_face_binding.gd` | `CDFaceBinding extends Resource` | Pairs a signal name and frame index for face components |

---

## Effects (2)

| Script | Class | Summary |
|--------|-------|---------|
| `broken_ship_effect.gd` | `BrokenTriangleEffect extends CDEffect` | Spinning line fragments that drift outward and fade |
| `death_particle_effect.gd` | `DeathParticleEffect extends CDEffect` | Burst of single-pixel particles that fly outward |

---

## Entity Components — Brains (17)

Pure intent generators (Priority 10). Never touch velocity, never move entities.

### Player Brains (5)

| Script | Class | Summary |
|--------|-------|---------|
| `player_move_brain.gd` | `PlayerMoveBrain extends CDEntityComponent` | Routes directional input from CDInputRouter to entity bus |
| `player_aim_brain.gd` | `PlayerAimBrain extends CDEntityComponent` | Routes aim input from CDInputRouter to entity bus |
| `player_action_brain.gd` | `PlayerActionBrain extends CDEntityComponent` | Routes action button presses/releases from CDInputRouter to entity bus |
| `player_move_to_brain.gd` | `PlayerMoveToBrain extends CDEntityComponent` | Emits "move_to" with mouse global position each physics frame |
| `player_kbm_move_brain.gd` | `PlayerKBMMoveBrain extends CDEntityComponent` | Unified KB+Mouse move brain — merges keyboard "move" and mouse "move_to" into single intent |

### AI: Targeting Brains (4)

| Script | Class | Summary |
|--------|-------|---------|
| `ai_chase_brain.gd` | `AIChaseBrain extends CDEntityComponent` | Emits movement direction towards nearest target in groups |
| `ai_flee_brain.gd` | `AIFleeBrain extends CDEntityComponent` | Emits movement direction away from nearest target in groups |
| `ai_aim_brain.gd` | `AIAimAtNearestBrain extends CDEntityComponent` | Emits aim direction towards nearest target in groups |
| `ai_orbit_brain.gd` | `AIOrbitBrain extends CDEntityComponent` | Emits movement direction orbiting a CDEntity with lock-on |

### AI: Action Brains (2)

| Script | Class | Summary |
|--------|-------|---------|
| `ai_repeat_action_brain.gd` | `AIRepeatActionBrain extends CDEntityComponent` | Fires action signal repeatedly on a timer while active |
| `ai_timed_step_brain.gd` | `AITimedStepBrain extends CDEntityComponent` | Emits directional signal at regular interval |

### AI: Path & Patrol Brains (5)

| Script | Class | Summary |
|--------|-------|---------|
| `ai_path_move_brain.gd` | `AIPathMoveBrain extends CDEntityComponent` | Follows a Curve2D resource, emitting positional waypoints |
| `ai_random_sweep_brain.gd` | `AIRandomSweepBrain extends CDEntityComponent` | Generates multi-waypoint sweep path across play area |
| `ai_idle_wander_brain.gd` | `AIIdleWanderBrain extends CDEntityComponent` | Picks random nearby points, meanders with idle pauses |
| `ai_formation_brain.gd` | `AIFormationBrain extends CDEntityComponent` | Moves to offset from leader entity with target locking |
| `ai_swoop_brain.gd` | `AISwoopBrain extends CDEntityComponent` | Follows CDCurve path via checkpoints, triggered by entity bus signal |

### AI: Special Brains (1)

| Script | Class | Summary |
|--------|-------|---------|
| `ai_tractor_beam_brain.gd` | `AITractorBeamBrain extends CDEntityComponent` | Interrupts dive to perform capture attempt |

---

## Entity Components — Arms (16)

World-affecting components (Priority 40). Consume collision signals, affect other entities or game state.

### Collision Response Arms (6)

| Script | Class | Summary |
|--------|-------|---------|
| `damage_on_hit_arm.gd` | `DamageOnHitArm extends CDEntityComponent` | Deals flat damage to whatever entity collides with |
| `death_on_hit_arm.gd` | `DeathOnHitArm extends CDEntityComponent` | Instantly kills whatever entity collides with |
| `damage_on_crash_arm.gd` | `DamageOnCrashArm extends CDEntityComponent` | Deals damage to self on any collision (mutual) |
| `death_on_crash_arm.gd` | `DeathOnCrashArm extends CDEntityComponent` | Kills self on any collision (mutual) |
| `damage_on_joust_arm.gd` | `DamageOnJoustArm extends CDEntityComponent` | Deals damage based on comparative property check |
| `death_on_joust_arm.gd` | `DeathOnJoustArm extends CDEntityComponent` | Kills based on comparative property check, bypasses health |

### Scoring Arms (2)

| Script | Class | Summary |
|--------|-------|---------|
| `score_on_collision_arm.gd` | `ScoreOnCollisionArm extends CDEntityComponent` | Emits score_gained on collision with valid target |
| `score_on_death_arm.gd` | `ScoreOnDeathArm extends CDEntityComponent` | Emits score_gained when entity dies |

### Force & Status Arms (2)

| Script | Class | Summary |
|--------|-------|---------|
| `pushback_arm.gd` | `PushbackArm extends CDEntityComponent` | Applies physical impulse to target's ImpulseReceiverGuts |
| `status_on_hit_arm.gd` | `StatusEffectArm extends CDEntityComponent` | Sends status effect signal and duration on collision |

### Spawn Arms (3)

| Script | Class | Summary |
|--------|-------|---------|
| `gun_arm.gd` | `GunArm extends CDEntityComponent` | Spawns projectile on fire signal, pool-backed with cooldown |
| `spawn_on_death_arm.gd` | `SpawnOnDeathArm extends CDEntityComponent` | Spawns entities when parent entity dies |
| `piece_splitter_arm.gd` | `PieceSplitterArm extends CDEntityComponent` | On piece_locked, spawns individual SettledCell entities |

### Power-Up Arms (2)

| Script | Class | Summary |
|--------|-------|---------|
| `powerup_delivery_arm.gd` | `PowerUpDeliveryArm extends CDEntityComponent` | Delivers a powerup to whatever entity collides with |
| `powerup_wingman_arm.gd` | `PowerupWingmanArm extends CDEntityComponent` | Spawns companion entity at player position on powerup received |

### Special Arms (1)

| Script | Class | Summary |
|--------|-------|---------|
| `tractor_beam_arm.gd` | `TractorBeamArm extends CDEntityComponent` | Active-frames arm that captures entities in tractor beam zone |

---

## Entity Components — Guts (19)

Internal state trackers (Priority 50). Hold entity state and emit signals on change.

### Collision & Shape (2)

| Script | Class | Summary |
|--------|-------|---------|
| `deflector_bounce_guts.gd` | `DeflectorBounceGuts extends CDEntityComponent` | Deflects off target groups with angled bounce physics |
| `shape_collider_guts.gd` | `ShapeColliderGuts extends CDEntityComponent` | Overrides CDEntity collision shape on setup and signal |

### Health & Death (3)

| Script | Class | Summary |
|--------|-------|---------|
| `healthpool_guts.gd` | `HealthpoolGuts extends CDEntityComponent` | Single source of truth for entity health value |
| `die_at_zero_health_guts.gd` | `DieAtZeroHealthGuts extends CDEntityComponent` | Kills entity when health reaches zero |
| `points_guts.gd` | `PointsGuts extends CDEntityComponent` | Data holder for point value |

### Self-Destruction (3)

| Script | Class | Summary |
|--------|-------|---------|
| `die_on_timer_guts.gd` | `DieOnTimerGuts extends CDEntityComponent` | Destroys entity after set duration |
| `die_out_of_bounds_guts.gd` | `DieOutOfBoundsGuts extends CDEntityComponent` | Destroys entity if it leaves game bounds |
| `die_offscreen_guts.gd` | `DieOffscreenGuts extends CDEntityComponent` | Destroys entity when it leaves all camera views |

### Force & Input (3)

| Script | Class | Summary |
|--------|-------|---------|
| `impulse_receiver_guts.gd` | `ImpulseReceiverGuts extends CDEntityComponent` | Applies external impulse forces to parent entity |
| `kbm_guts.gd` | `KBMGuts extends CDEntityComponent` | Merges keyboard "move" and mouse "move_to" into single "steer" signal |
| `move_adapter_guts.gd` | `MoveAdapterGuts extends CDEntityComponent` | Converts "move_to" target positions into "move" direction vectors |

### Resource Pools (2)

| Script | Class | Summary |
|--------|-------|---------|
| `shieldpool_guts.gd` | `ShieldpoolGuts extends CDEntityComponent` | Rechargeable health buffer, "catch and release" signal pattern |
| `resourcepool_guts.gd` | `ResourcepoolGuts extends CDEntityComponent` | Generic pool for any entity resource |

### Status Effects (1)

| Script | Class | Summary |
|--------|-------|---------|
| `stun_guts.gd` | `StunGuts extends CDEntityComponent` | Temporarily disables Brains and Legs on stun status |

### Grid / Tetris (2)

| Script | Class | Summary |
|--------|-------|---------|
| `lock_detector_guts.gd` | `LockDetectorGuts extends CDEntityComponent` | Detects when grid entity can't fall further, manages lock delay |
| `t_spin_detector_guts.gd` | `TSpinDetectorGuts extends CDEntityComponent` | SRS 3-corner rule T-Spin detection with full/mini classification |

### Timers & Signals (2)

| Script | Class | Summary |
|--------|-------|---------|
| `timer_guts.gd` | `TimerGuts extends CDEntityComponent` | Emits tick and expired signals on a timer |
| `announcer_guts.gd` | `AnnouncerGuts extends CDEntityComponent` | Listens for entity bus signals, rebroadcasts on game bus |

### Vision (1)

| Script | Class | Summary |
|--------|-------|---------|
| `vision_cone_guts.gd` | `VisionConeGuts extends CDEntityComponent` | Forward-facing vision cone that detects bodies |

---

## Entity Components — Legs (15)

Movement executors (Priority 20). Consume entity bus signals, submit velocity/position requests.

### Continuous Physics (6)

| Script | Class | Summary |
|--------|-------|---------|
| `direct_movement_leg.gd` | `DirectMovementLeg extends CDEntityComponent` | Hard-sets velocity from directional input |
| `acceleration_movement_leg.gd` | `AccelerationLeg extends CDEntityComponent` | Accelerates toward input direction |
| `engine_leg.gd` | `EngineLeg extends CDEntityComponent` | Forward velocity based on facing direction (Asteroids-style) |
| `linear_friction_leg.gd` | `LinearFrictionLeg extends CDEntityComponent` | Linearly scaling friction from 0 to top speed |
| `static_friction_leg.gd` | `FrictionStatic extends CDEntityComponent` | Constant deceleration until velocity reaches zero |
| `boomerang_leg.gd` | `BoomerangLeg extends CDEntityComponent` | Constant return force toward spawn position |

### Rotation (2)

| Script | Class | Summary |
|--------|-------|---------|
| `direct_rotation_leg.gd` | `DirectRotationLeg extends CDEntityComponent` | Tank-style continuous rotation |
| `target_rotation_leg.gd` | `TargetRotationLeg extends CDEntityComponent` | Rotates toward aim direction |

### Grid (4)

| Script | Class | Summary |
|--------|-------|---------|
| `grid_movement_leg.gd` | `GridMovementLeg extends CDEntityComponent` | Fixed grid step if target cell unoccupied |
| `grid_rotation_leg.gd` | `GridRotationLeg extends CDEntityComponent` | Tetris-style rotation with wall-kick tables |
| `grid_drop_leg.gd` | `GridDropLeg extends CDEntityComponent` | Drops entity by N grid cells |
| `grid_alignment_leg.gd` | `GridAlignmentLeg extends CDEntityComponent` | Ensures entity stays snapped to pseudo-grid |

### Position-Targeting (2)

| Script | Class | Summary |
|--------|-------|---------|
| `direct_target_leg.gd` | `DirectTargetLeg extends CDEntityComponent` | Constant speed toward world-space target |
| `acceleration_target_leg.gd` | `AccelerationTargetLeg extends CDEntityComponent` | Accelerates toward target, tapers on approach |

### Spatial Utility (1)

| Script | Class | Summary |
|--------|-------|---------|
| `screen_wrap_leg.gd` | `ScreenWrapLeg extends CDEntityComponent` | Wraps entity to opposite side when out of bounds |

---

## Entity Components — Faces (7)

Visual representation components (Priority 60). Draw the entity's appearance.

| Script | Class | Summary |
|--------|-------|---------|
| `polygon_face.gd` | `PolygonFace extends CDEntityComponent` | Draws filled polygons from CDShape resources |
| `vector_face.gd` | `VectorFace extends CDEntityComponent` | Draws polylines from CDShape resources |
| `menacing_vector_face.gd` | `MenacingVectorFace extends VectorFace` | Vector face with CRT menace effects: glitch, static, glow, scan, corrupt |
| `sprite_face.gd` | `SpriteFace extends CDEntityComponent` | Draws Texture2D, swaps texture based on signal-to-frame bindings |
| `death_effect_face.gd` | `DeathEffectFace extends CDEntityComponent` | Spawns CDEffect scenes at entity position when it dies |
| `vector_engine_face.gd` | `VectorEngineFace extends CDEntityComponent` | Main engine exhaust flame for Asteroids-style ship |
| `vector_thruster_face.gd` | `VectorThrusterFace extends CDEntityComponent` | Four vector engine flames in an X pattern |

---

## Entity Components — Voices (2)

Entity-level audio components.

| Script | Class | Summary |
|--------|-------|---------|
| `sound_voice.gd` | `SoundVoice extends CDEntityComponent` | One-shot or jingle triggered by entity bus signal |
| `continuous_voice.gd` | `ContinuousVoice extends CDEntityComponent` | Ongoing sound tied to entity state |

---

## Game Components — Cue Cards (4)

Stage-level display components (Priority 70). Extend CDCueCard (Control-based).

| Script | Class | Summary |
|--------|-------|---------|
| `score_card.gd` | `ScoreCard extends CDCueCard` | Tracks score with optional multiplier |
| `lives_card.gd` | `LivesCard extends CDCueCard` | Tracks player lives |
| `timer_card.gd` | `TimerCard extends CDCueCard` | Tracks time and emits signals |
| `wave_card.gd` | `WaveCard extends CDCueCard` | Tracks current wave number, signal relay for spawners |

---

## Game Components — Directors (7)

Stage-level controllers that manage entity behavior at the game level.

| Script | Class | Summary |
|--------|-------|---------|
| `stage_director.gd` | `StageDirector extends CDGameComponent` | Listens for game bus signals, performs entity swaps |
| `state_director.gd` | `StateDirector extends CDGameComponent` | Updates entity groups for group-as-state management |
| `formation_director.gd` | `FormationDirector extends CDGameComponent` | Manages a grid of named slots with fill-direction priority |
| `shooting_director.gd` | `ShootingDirector extends CDGameComponent` | Data-driven shooting: CDTrigger decides WHEN, CDSelector decides WHO |
| `aiming_director.gd` | `AimingDirector extends CDGameComponent` | Per-entity nearest-target aiming across groups |
| `swoop_director.gd` | `SwoopDirector extends CDGameComponent` | Generates curve from CDCurve resource, moves entities along it |
| `signal_sequence_director.gd` | `SignalSequenceDirector extends CDGameComponent` | Data-driven signal macro — turns one trigger into a timed signal sequence |

---

## Game Components — Goals (2)

Stage-level game-end condition triggers.

| Script | Class | Summary |
|--------|-------|---------|
| `group_count_goal.gd` | `GroupCountGoal extends CDGameComponent` | Triggers when group counts match a condition |
| `score_threshold_goal.gd` | `ScoreThresholdGoal extends CDGameComponent` | Triggers when score crosses a threshold |

---

## Game Components — Marks (6)

Stage-level spatial detectors. Area2D-based triggers that emit on body contact.

| Script | Class | Summary |
|--------|-------|---------|
| `cd_mark.gd` | `CDMark extends Area2D` | Emits signals on body entered and exited |
| `count_mark.gd` | `CountMark extends CDMark` | Emits after N unique bodies have entered |
| `mobile_mark.gd` | `MobileMark extends CDMark` | Follows a target CDEntity with lock-on |
| `timed_mark.gd` | `TimedMark extends CDMark` | Emits while body remains inside zone for configured duration |
| `safe_zone_mark.gd` | `SafeZoneMark extends CDMark` | Spawn-safety monitor for trapdoors |
| `occupancy_mark.gd` | `OccupancyMark extends CDMark` | Occupancy tracker, emits on enter/exit |

---

## Game Components — Projectors (2)

Stage-level visual post-processing.

| Script | Class | Summary |
|--------|-------|---------|
| `crt_projector.gd` | `CRTProjector extends CDGameComponent` | CRT post-processing pipeline for V2 |
| `credit_projection.gd` | `CreditProjection extends Control` | Floating credit overlay showing track title and artist |

---

## Game Components — Speakers (3)

Stage-level audio components.

| Script | Class | Summary |
|--------|-------|---------|
| `sound_speaker.gd` | `SoundSpeaker extends CDGameComponent` | Game-level one-shot or jingle triggered by game bus signal |
| `continuous_speaker.gd` | `ContinuousSpeaker extends CDGameComponent` | Game-level continuous sound |
| `music_speaker.gd` | `MusicSpeaker extends CDGameComponent` | Playlist + dual-player crossfade + loop-point logic |

---

## Game Components — Trapdoors (3)

Stage-level spawners. Subscribe to game bus signals, queue and stagger-spawn entities.

| Script | Class | Summary |
|--------|-------|---------|
| `point_trapdoor.gd` | `PointTrapdoor extends CDStageTrapdoor` | Spawns entities at its own position |
| `edge_trapdoor.gd` | `EdgeTrapdoor extends CDStageTrapdoor` | Spawns entities along selected edges of game bounds |
| `grid_trapdoor.gd` | `GridTrapdoor extends CDStageTrapdoor` | Spawns entities in a 2D grid using data or math |

---

## Component Count Summary

| Category | Count |
|----------|-------|
| Core Base Classes | 4 |
| Core Infrastructure | 10 |
| Core Resources: Infrastructure | 3 |
| Core Resources: Audio | 3 |
| Core Resources: Behavior | 8 |
| Core Resources: Curves | 13 |
| Core Resources: Selectors | 7 |
| Core Resources: Spawners | 4 |
| Core Resources: Triggers | 5 |
| Core Resources: Formation | 2 |
| Core Resources: Visuals | 1 |
| Effects | 2 |
| Brains | 17 |
| Arms | 16 |
| Guts | 19 |
| Legs | 15 |
| Faces | 7 |
| Voices | 2 |
| Cue Cards | 4 |
| Directors | 7 |
| Goals | 2 |
| Marks | 6 |
| Projectors | 2 |
| Speakers | 3 |
| Trapdoors | 3 |
| **Total V2 Scripts** | **165** |
