# Project Status — CD50

> **Source of truth for what exists in the codebase.**
> Architecture overview + complete component catalogue.
> Update this file when scripts are added, removed, or renamed.

**Last Updated:** 2026-06-28
**Architecture:** V2 Composable Architecture
**Total V2 Scripts:** 191
**Active Game:** Bug Blaster 2 (first V2 game — complete, serves as the proving ground)
**V1:** Archived under `Godot/v1/`, kept as reference until V2 reaches parity, then deleted.

**Companion docs:** `USAGE.md` (deep architecture guide) · `CONVENTIONS.md` (AI editing rules) · `CURRENT_TASK.md` (active work)

---

## Architecture Overview

The V2 architecture builds every game from generic, reusable components — **zero game-specific scripts**. Entities are blank physics shells (`CDEntity`); all behavior is injected by attaching components. Components communicate via two signal buses (entity bus + game bus) using **zero-arg signals**, with data flowing through `entity.blackboard` / `game.blackboard` dictionaries. Processing order is deterministic via a priority cascade.

### The Three Rules
1. **Composition over inheritance** — `CDEntity` is a blank physics shell. All behavior comes from components.
2. **Signals, not calls** — Components never call methods on other components. They emit signals.
3. **Single-purpose components** — Each component does one thing. Split if it does two.

### Priority Cascade
```
REGISTRY(5) → INPUT(8) → BRAINS(10) → LEGS(20) → ENTITY(30) → COLLISION(35) → ARMS(40) → GUTS(50) → FACES(60) → VOICES(65) → STAGE(70) → MANAGER(75) → UPDATE(90)
```
Reserved for infrastructure (never set by components): `REGISTRATION`, `INPUT`, `ENTITY`, `COLLISION`, `UPDATE`.

### Component Categories
| Category | Priority | Purpose |
|:---|:---|:---|
| **Brains** (INTENT) | 10 | Input / AI — pure intent generators, never touch velocity |
| **Legs** (STEERING) | 20 | Movement executors — consume intent, submit velocity requests |
| **Arms** (INTERACTION) | 40 | World-affecting — collision response, scoring, spawning |
| **Guts** (STATE) | 50 | Internal state trackers — health, timers, resources, detection |
| **Faces** (VISUAL) | 60 | Visual representation — drawing code only |
| **Voices** (AUDIO) | 65 | Entity-level audio |
| **Stage** (RULES) | 70 | Game-level components — cards, goals, marks, directors, trapdoors, speakers, projectors |
| **Managers** | 75 | Stage lifecycle & cross-frame state |

> **Manager vs Director boundary:** Both live in `game components/`. **Directors** (`RULES`/70) orchestrate across groups each frame — they gather entities, evaluate data-driven rules, and push intent onto blackboards/signals or perform one-shot swaps. **Managers** (`MANAGER`/75) own lifecycle and accumulated state — staging entities in/out, running timed signal sequences, evaluating scoring rules, transitioning entities between groups.

See `USAGE.md` for the full explanation of how these systems fit together.

---

## Component Catalogue

### Core — Base Classes (4)
| Class | Purpose |
|:---|:---|
| `CDEntityComponent` | Entity component base — two-phase lifecycle, category priority |
| `CDGameComponent` | Game-level component base — same lifecycle, no entity ref, cached `game`, tracked bus API |
| `CDCueCard` | Base for UI cards — `_update_label`, `_publish_tracked`, `_consume_pending` |
| `CDStageTrapdoor` | Spawner base — trigger/queue/stagger/spawn lifecycle; concrete subclasses only override virtuals |

### Core — Infrastructure (12)
| Class | Purpose |
|:---|:---|
| `CDEntity` | Blank physics shell (`CharacterBody2D`) — velocity accumulator, entity bus, blackboard, pool-aware lifecycle |
| `CDGame` | Game root (`Node2D`) — game bus + blackboard, state machine, no game logic |
| `CDBody` | Behavior-set container inside an entity — sleeps/wakes on signals; holds its own components |
| `CDStage` | Scene container — sleeps/wakes on signals; holds trapdoors/directors for one level/section |
| `CDCollisionBuffer` | Resolves collision intents into physics events each frame |
| `CDCollisionMatrix` | Data-driven collision rules between named groups |
| `CDGroupRegistry` | Tracks active entities by group; queries (union, nearest, counts) |
| `CDInputRouter` | Routes Godot input to the focused entity's brains |
| `CDObjectPool` | Recycles entities/components to avoid per-frame allocation |
| `CDSoundBank` | Procedural audio engine — one-shot + continuous synthesized playback |
| `CDEffect` | Base for transient visual effects (pool-friendly lifecycle) |
| `CDUpdater` | Deferred-work queue — flushes transitions after the current frame |

### Core — Resources (53)

#### Audio (3)
| Class | Purpose |
|:---|:---|
| `CDNote` | One synthesized note (frequency, duration, glide) |
| `CDSoundDef` | A sequence of `CDNote`s with wave shape + effect + volume |
| `CDMusicTrack` | Streamed music asset with loop points + metadata |

#### Behavior (10)
| Class | Purpose |
|:---|:---|
| `CDTrigger` | Base — decides *when* something fires (signal/timer/group-count/composite) |
| `CDCompositeTrigger` | Combines multiple triggers (AND) |
| `CDSelector` | Base — decides *which* entities a rule targets |
| `CDScaler` | Base — scales a value (speed, count) by wave/data |
| `CDWaveScaler` | Scales a value per wave, clamped to min/max |
| `CDGroupCountScaler` | Scales a value by an entity group's count |
| `CDScoringRule` | Score + multiplier delta bound to a trigger |
| `CDSequenceStep` | One step in a timed signal sequence |
| `CDStageRule` | Sleep/wake stage list bound to a trigger |
| `CDTransition` | Move entities between groups (group-as-state), bound to trigger + selector |

#### Curves (13)
| Class | Purpose |
|:---|:---|
| `CDCurve` | Base — parametric path for AI movement/swoop |
| `CDArcCurve` | Arc path |
| `CDCircleCurve` | Circular/elliptical loop |
| `CDHelixCurve` | Helical path |
| `CDLissajousCurve` | Lissajous figure |
| `CDParabolaCurve` | Parabolic dive path |
| `CDSequenceCurve` | Chains multiple curves end-to-end |
| `CDSineCurve` | Sine wave path |
| `CDSawtoothWaveCurve` | Sawtooth path |
| `CDSquareWaveCurve` | Square wave path |
| `CDTriangleCurve` | Triangle path |
| `CDZigzagCurve` | Zigzag path |
| `CDSpiralCurve` | Spiral (inward/outward) |

#### Formation (6)
| Class | Purpose |
|:---|:---|
| `CDFormation` | Grid slot layout (columns/rows/offset) for a group |
| `CDMarchingOrder` | Sequence of steps that march a formation over time |
| `MarchingOrderStep` | One translate step in a marching order |
| `MarchingOrderBreathe` | Breathing (oscillating spacing) step |
| `MarchingOrderPause` | Hold-position step |
| `MarchingOrderRepeat` | Loop a sub-sequence |

#### Selectors (8)
| Class | Purpose |
|:---|:---|
| `CDSelectAll` | Target every entity in the groups |
| `CDSelectByKey` | Target entities matching a blackboard key/value |
| `CDSelectNearestN` | Target the N nearest to a position |
| `CDSelectNearestNToGroup` | Target the N nearest to a group's centroid |
| `CDSelectN` | Target the first N |
| `CDSelectRandomN` | Target N random entities |
| `CDSelectSignalEmitter` | Target the entity that emitted the current-frame signal |

#### Spawners (4)
| Class | Purpose |
|:---|:---|
| `CDSpawnContext` | Extra groups + rotation applied to a spawned entity |
| `CDGridLayout` | Grid spawn layout (rows/cols/spacing) |
| `CDGridRow` | One row definition for grid spawning |
| `CDGridEquation` | Expression-driven spawn count/position |

#### Triggers (5)
| Class | Purpose |
|:---|:---|
| `CDSignalTrigger` | Fires on a named game-bus signal |
| `CDTimerTrigger` | Fires on an interval (with variance) |
| `CDGroupCountTrigger` | Fires when a group count meets a comparison |
| `CDCompositeTrigger` | Fires when all sub-triggers fire (AND) |
| *(base `CDTrigger` listed under Behavior)* | |

#### Infrastructure (3)
| Class | Purpose |
|:---|:---|
| `CDCollisionGroup` | Names a group + who it collides with |
| `CDEnums` | Enums (categories, game state, comparisons) + `compare()` helper |
| `CDUtilities` | Helpers (`MIX_RATE`, `freq_from_note`, `evaluate_int`, etc.) |

#### Visuals (1)
| Class | Purpose |
|:---|:---|
| `CDFaceBinding` | Binds a face component's drawing to entity state |

---

### Entity Components

#### Brains (17) — Priority 10 — intent generators
| Subfolder | Class | Purpose |
|:---|:---|:---|
| player | `PlayerMoveBrain` | Keyboard move intent → `"move"` |
| player | `PlayerKBMMoveBrain` | KB+mouse variant move intent |
| player | `PlayerMoveToBrain` | Click/move-to-target intent |
| player | `PlayerActionBrain` | Action button → `"fire"`/`"thrust"` etc. |
| player | `PlayerAimBrain` | Aim intent from pointer |
| ai action | `AIAimBrain` | AI aim intent |
| ai action | `AIRepeatActionBrain` | Repeats an action on a cadence |
| ai action | `AITractorBeamBrain` | Fires tractor beam on a signal |
| ai action | `LassoBrain` | Fires lasso/grapple intent |
| ai movement | `AIChaseBrain` | Pursue a target |
| ai movement | `AIEscortBrain` | Follow a leader with offset (capture/rescue) |
| ai movement | `AIFleeBrain` | Evade a target |
| ai movement | `AIFormationBrain` | Hold a formation slot |
| ai movement | `AIIdleWanderBrain` | Drift randomly when idle |
| ai movement | `AIOrbitBrain` | Orbit a target |
| ai movement | `AIPathMoveBrain` | Follow a `CDCurve` path |
| ai movement | `AIRandomSweepBrain` | Random sweep pattern |
| ai movement | `AISwoopBrain` | Swoop along a curve at a target |
| ai movement | `AITimedStepBrain` | Step movement on a timer |

#### Legs (15) — Priority 20 — movement executors
| Subfolder | Class | Purpose |
|:---|:---|:---|
| directional adders | `DirectMovementLeg` | Apply intent as direct velocity |
| directional adders | `AccelerationMovementLeg` | Accelerate toward intent |
| directional adders | `EngineLeg` | Thrust-based acceleration |
| directional setters | `DirectRotationLeg` | Snap rotation to direction |
| directional setters | `GridMovementLeg` | Grid-snapped movement |
| directional setters | `GridRotationLeg` | Grid-snapped rotation |
| positional adders | `AccelerationTargetLeg` | Accelerate toward a target point |
| positional setters | `DirectTargetLeg` | Move directly to a target point |
| positional setters | `TargetRotationLeg` | Rotate to face a target |
| other | `BoomerangLeg` | Out-and-back path |
| other | `GridAlignmentLeg` | Align to grid lanes |
| other | `GridDropLeg` | Downward grid drop (block drop) |
| other | `LeaderTeleportLeg` | Teleport to leader offset |
| other | `LinearFrictionLeg` | Apply linear damping |
| other | `ScreenWrapLeg` | Wrap around screen edges |
| other | `StaticFrictionLeg` | Hard stop when no intent |

#### Arms (16) — Priority 40 — world interaction
| Subfolder | Class | Purpose |
|:---|:---|:---|
| collision reactions | `CaptureOnHitArm` | Capture a body on collision (Galaga tractor) |
| collision reactions | `DamageOnCrashArm` | Apply damage on crash |
| collision reactions | `DamageOnHitArm` | Apply damage on hit |
| collision reactions | `DamageOnJoustArm` | Joust-style collision damage |
| collision reactions | `DeathOnCrashArm` | Kill on crash |
| collision reactions | `DeathOnHitArm` | Kill on hit |
| collision reactions | `DeathOnJoustArm` | Joust-style death |
| collision reactions | `PushbackArm` | Push colliding bodies apart |
| collision reactions | `ScoreOnCollisionArm` | Award score on collision |
| collision reactions | `StatusOnHitArm` | Apply a status on hit |
| death reactions | `ScoreOnDeathArm` | Award score when this entity dies |
| death reactions | `SpawnOnDeathArm` | Spawn a scene on death |
| other | `PieceSplitterArm` | Split a piece (block drop) |
| powerup arms | `PowerupDeliveryArm` | Deliver a powerup to recipient |
| powerup arms | `PowerupWingmanArm` | Grant a wingman powerup |
| triggered arms | `GunArm` | Fire projectiles |
| triggered arms | `LassoArm` | Fire a lasso/grapple projectile |
| triggered arms | `TractorBeamArm` | Activate tractor beam capture zone |

#### Guts (19) — Priority 50 — internal state
| Subfolder | Class | Purpose |
|:---|:---|:---|
| death | `DieAtZeroHealthGuts` | Emit death when health hits zero |
| death | `DieOffscreenGuts` | Emit death when offscreen |
| death | `DieOnTimerGuts` | Emit death after a timer |
| death | `DieOutOfBoundsGuts` | Emit death out of bounds |
| detection | `LeaderTrackerGuts` | Track a leader entity; emit when it dies |
| detection | `LockDetectorGuts` | Detect lock-on conditions |
| detection | `VisionConeGuts` | Vision cone sensor |
| game logic | `AnnouncerGuts` | Listen + rebroadcast signals (relay) |
| game logic | `PointsGuts` | Hold point value (for scoring) |
| game logic | `StunGuts` | Track stun state |
| game logic | `TimerGuts` | Internal timer state |
| game logic | `TSpinDetectorGuts` | Detect T-spin (block drop) |
| input | `KBMGuts` | KB+mouse input state |
| input | `MoveAdapterGuts` | Adapt input into move intent |
| physics | `DeflectorBounceGuts` | Bounce off deflector surfaces |
| physics | `ImpulseReceiverGuts` | Receive and decay impulses |
| physics | `ShapeColliderGuts` | Per-shape collision config |
| pools | `HealthpoolGuts` | Health pool (+ multiplier-aware delta) |
| pools | `ResourcepoolGuts` | Generic resource pool |
| pools | `ShieldpoolGuts` | Shield pool (absorbs damage first) |

#### Faces (7) — Priority 60 — visual
| Class | Purpose |
|:---|:---|
| `VectorFace` | Procedural vector-line ship drawing |
| `VectorEngineFace` | Vector ship + engine flame |
| `VectorThrusterFace` | Vector ship + thrusters |
| `MenacingVectorFace` | Vector ship with menacing styling |
| `PolygonFace` | Solid polygon drawing |
| `SpriteFace` | Sprite-based appearance |
| `TractorBeamFace` | Tractor beam visual |
| `DeathEffectFace` | Spawns a death effect on death |

#### Voices (2) — Priority 65 — entity audio
| Class | Purpose |
|:---|:---|
| `SoundVoice` | One-shot synthesized sound on a signal |
| `ContinuousVoice` | Sustained synthesized tone (drone/hum) |

---

### Game Components

#### Cards (5) — Priority 70 — tracked-state UI
| Class | Tracks |
|:---|:---|
| `ScoreCard` | Score + multiplier |
| `LivesCard` | Player lives (emits depleted) |
| `TimerCard` | Countdown/count-up timer |
| `WaveCard` | Current wave number |
| `CaptureCard` | Active capture count + captured-entity cleanup |

#### Directors (6) — Priority 70 — group orchestration
| Class | Output |
|:---|:---|
| `AimingDirector` | Blackboard `aim_direction` per entity |
| `FormationDirector` | Blackboard `move_direction`/`move_distance` (slot grid + marching) |
| `MarchingOrderDirector` | Blackboard `move_direction`/`move_distance` (path delta) |
| `ShootingDirector` | Entity-bus shoot signal (trigger + selector driven) |
| `SwoopDirector` | Blackboard move along a curve; emits `swoop_complete` |
| `StageDirector` | Entity swap (deactivate + spawn replacement) on game-bus signal |

#### Managers (4) — Priority 75 — lifecycle & accumulated state
| Class | Resource type | Purpose |
|:---|:---|:---|
| `ScoreManager` | `CDScoringRule` | Applies score/multiplier deltas |
| `SignalManager` | `CDSequenceStep` | Runs timed signal sequences |
| `StageManager` | `CDStageRule` | Sleeps/wakes `CDStage` nodes on triggers |
| `StateManager` | `CDTransition` | Moves entities between groups (state), deferred |

#### Goals (3) — Priority 70 — win/lose
| Class | Watches |
|:---|:---|
| `GroupCountGoal` | `CDGroupRegistry` entity counts |
| `ScoreThresholdGoal` | An `int` on `game.blackboard` |
| `SignalGoal` | Game-bus signals (no numeric condition) |

#### Marks (6) — spatial triggers
| Class | Pattern |
|:---|:---|
| `CDMark` | Base — group-filtered `Area2D`, blackboard + game-bus + entity-bus signals |
| `CountMark` | Counts unique bodies; fires at target count |
| `MobileMark` | Lerps to follow a target entity |
| `OccupancyMark` | Per-group occupancy counter |
| `SafeZoneMark` | Safe/unsafe state sensor |
| `TimedMark` | Times how long bodies stay inside |

#### Projectors (3) — visual overlays
| Class | Base | Purpose |
|:---|:---|:---|
| `CDGameControl` | `Control` | Base for `Control`-rooted game nodes |
| `CreditProjection` | `CDGameControl` | Floating "now playing" credit overlay |
| `CRTProjector` | `CDGameComponent` | Full-screen CRT post-processing |

#### Speakers (3) — game audio
| Class | Audio source | Purpose |
|:---|:---|:---|
| `ContinuousSpeaker` | `CDSoundBank` continuous | Sustained synthesized tone |
| `MusicSpeaker` | `CDMusicTrack` + `AudioStreamPlayer` | Shuffled playlist with crossfade/loop |
| `SoundSpeaker` | `CDSoundBank` one-shot | One-shot synthesized sound |

#### Trapdoors (3) — spawners
| Class | Pattern |
|:---|:---|
| `EdgeTrapdoor` | Distributed along `game_bounds` edges |
| `GridTrapdoor` | Centered 2D grid (`@tool` preview) |
| `PointTrapdoor` | All spawns at the trapdoor's position |

---

### Effects (6)
| Class | Purpose |
|:---|:---|
| `BrokenShipEffect` | Debris effect for destroyed ships |
| `DeathParticleEffect` | Particle burst on death |
| `LassoEffect` | Visual for lasso/grapple |
| `ScrollingStarsEffect` | Scrolling starfield background |
| `TractorConeEffect` | Tractor beam cone visual |
| `TwinklingStarsEffect` | Twinkling starfield background |