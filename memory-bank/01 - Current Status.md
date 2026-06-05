# Current Status: CD50 — Arcade Cabinet

**Last Updated:** 2026-06-04  
**Engine:** Godot 4.5 (GDScript)  
**Architecture:** V2 Composable Architecture (active development) — V1 archived to `Godot/v1/`  
**Playable Games:** Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop (Modern), Rock Breaker, Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted — ALL componentized, zero game scripts
**In Progress:** Bug Blaster 2 (Galaga) — partially implemented. Formation, swoop/dive, shooting, StateDirector dive cycle all functional. Remaining: capture ships, capture mechanics, multiple waves.
**Recent Completed:** Plans 19–28 complete. Plan 28 adds MANAGER category (priority 75), StageManager/StateManager/SignalManager components, CDStageRule resource. CDStage simplified (sleep_on/wake_on removed → StageManager handles stage control). 170 V2 scripts written.
**Demo Status:** Code-locked at 12 games. Polybius character complete (7 scripts, 5 voice lines, full AO intro/outro integration). Only shipping tasks remain (flip itch to public, add Steam wishlist link). Itch.io demo stays on V1 architecture.

**Key Documentation:**
- `USAGE.md` — Complete patterns, anti-patterns, and code quality guide for the V2 architecture
- `memory-bank/05 - Patterns & Anti-Patterns.md` — Quick-reference index for AI agents
- `memory-bank/07 - Component Catalogue V2.md` — Full V2 component inventory (165 scripts)
- `planning/V2 Rules.md` — Canonical V2 design reference

---

## Project Overview

CD50 is a modular arcade game collection built around a composable component architecture. Every game is assembled from reusable components (Brains, Legs, Arms, Guts, Faces, Voices, Stage) attached to generic `CDEntity` and `CDGame` base classes. No game-specific scripts exist.

**All games run as pure scene assemblies.** See `USAGE.md` for the complete architecture guide.

---

## V2 Core Infrastructure

All V2 core scripts live in `Godot/scripts/core/`. Full details in `USAGE.md`.

| Script | Class | Role |
|--------|-------|------|
| `cdentity.gd` | `CDEntity extends CharacterBody2D` | Blank physics shell — velocity accumulator, entity bus, pool-aware lifecycle |
| `cdgame.gd` | `CDGame extends Node2D` | Game root — native signal bus + blackboard, state machine, no game logic |
| `cd_entity_component.gd` | `CDComponent2D extends Node2D` | Entity component base — two-phase lifecycle, category priority |
| `cd_game_component.gd` | `CDStageComponent2D extends Node2D` | Stage component base — same lifecycle, no entity ref |
| `cd_collision_buffer.gd` | `CDCollisionBuffer` | Deferred collision flush at Priority 35 |
| `cd_group_registry.gd` | `CDGroupRegistry` | Single source of truth for group counts |
| `cd_collision_matrix.gd` | `CDCollisionMatrix` | Auto-configures physics layers from CDCollisionGroup resources |
| `cd_input_router.gd` | `CDInputRouter` | Pure signal emitter autoload for player input |
| `cd_object_pool.gd` | `CDObjectPool` | Per-type entity pool with acquire/return lifecycle |
| `cd_updater.gd` | `CDUpdater` | Defers state mutations + sleep/wake queues to Priority 90 |
| `cd_stage.gd` | `CDStage` | Game-level container — sleeps/wakes child CDGameComponents as a group (control via StageManager) |
| `cd_body.gd` | `CDBody` | Entity-level container — sleeps/wakes child CDEntityComponents as a group |
| `cd_effect.gd` | `CDEffect` | Lightweight visual effect base — plays once and auto-frees |
| `cd_sound_bank.gd` | `CDSoundBank` | Centralized audio engine for V2 |
| `cd_enums.gd` | `CDEnums` | Shared enumerations — ComponentCategory, EntityState, GameState, etc. |

---

## V2 Component Count

| Category | Priority | Count | Key Components |
|----------|----------|-------|----------------|
| Core | varies | ~12 | CDEntity, CDGame, CDComponent2D, CDStageComponent2D, CDCollisionBuffer, CDGroupRegistry, etc. |
| Brains (INTENT) | 10 | 17 | PlayerMove/Aim/Action/MoveTo/KBMMoveBrain, AIChase/Flee/Orbit/Formation/Aim/RepeatAction/TractorBeam/PathMove/RandomSweep/TimedStep/IdleWanderBrain, AISwoopBrain |
| Legs (STEERING) | 20 | 15 | DirectMovement/Acceleration/Engine/Target/RotationLeg, GridMovement/Rotation/Drop/AlignmentLeg, Friction, ScreenWrap |
| Arms (INTERACTION) | 40 | 16 | DamageOnHit/Crash/Joust, DeathOnHit/Crash/Joust, ScoreOnCollision/Death, Pushback, StatusOnHit, GunArm, SpawnOnDeath, PowerupDelivery/Wingman, TractorBeam, PieceSplitter |
| Guts (STATE) | 50 | 19 | Healthpool/Shieldpool/Resourcepool, DieAtZeroHealth/Offscreen/OnTimer/OutOfBounds, DeflectorBounce/ImpulseReceiver/ShapeCollider, LockDetector/VisionCone, KBM/MoveAdapter, Announcer/Points/Stun/TSpinDetector/Timer |
| Faces (VISUAL) | 60 | 7 | VectorFace, PolygonFace, SpriteFace, VectorEngineFace, VectorThrusterFace, DeathEffectFace, MenacingVectorFace |
| Voices (AUDIO) | 65 | 2 | SoundVoice, ContinuousVoice |
| Stage (RULES) | 70 | 27 | ScoreCard, LivesCard, TimerCard, WaveCard, Goals, Directors, Marks, Speakers, Projectors, Trapdoors |
| Managers | 75 | 3 | StageManager, StateManager, SignalManager |

**Total: 170 V2 scripts + 47 custom resources**

Full catalogue: `memory-bank/07 - Component Catalogue V2.md`

---

## V2 Architecture (Complete)

The V2 Composable Architecture is a full refactor of the ECS for the desktop/Steam version. **Canonical reference:** `planning/V2 Rules.md`

### Key Changes from V1

| Aspect | V1 (Current) | V2 (Planned) |
|--------|-------------|--------------|
| Entity base | `UniversalBody` | `CDEntity` — velocity accumulator, entity bus, pool-aware lifecycle |
| Game base | `UniversalGameScript` | `CDGame` — game bus (Dictionary), state machine, no game logic |
| Component base | `UniversalComponent` / `UniversalComponent2D` | `CDComponent2D` — two-phase lifecycle, category priority |
| Signal system | Body routes input→output | Hybrid bus: both native signals + blackboard. Dynamic signals are zero-arg, data via `entity.blackboard` / `game.blackboard` |
| Processing | No fixed ordering | Deterministic priority cascade (5→10→20→30→35→40→50→60→65→70→75→90) |
| Collision | Direct in physics process | `CDCollisionBuffer` flushes at Priority 35 |
| Groups | `group_cache.gd` (lazy dirty flag) | `CDGroupRegistry` — single source of truth, emits `group_count_changed` |
| Spawning | `WaveSpawner` inline | `CDStageSpawner` + `CDObjectPool` — separate acquire/activate |
| Component categories | Brains, Legs, Arms, Components, Rules, Flow | Brains, Legs, Arms, Guts, Faces, Voices, Stage, Speakers, Spawners |
| Collision response | `damage_on_hit`, `die_on_hit` (case-by-case) | 2×2 matrix: DamageOnHit/Crash, DeathOnHit/Crash + Joust variants |
| Internal state | Mixed into Components category | Dedicated **Guts** category (health, timers, resources, lock detection) |

### V2 Directory Structure

```
Godot/scripts/
├── core/
│   ├── base classes/            — CDEntityComponent, CDGameComponent, CDCueCard, CDStageTrapdoor (4)
│   ├── infrastructure/          — CDEntity, CDGame, CDCollisionBuffer, CDGroupRegistry, etc. (10)
│   └── resources/
│       ├── audio/               — CDNote, CDSoundDef, CDMusicTrack (3)
│       ├── behavior/            — CDTransition, CDShape, CDScaler, CDSequenceStep, etc. (8)
│       ├── curves/              — CDCurve base + 12 curve types (13)
│       ├── formation/           — CDFormation, CDMarchingOrder (2)
│       ├── infrastructure/      — CDCollisionGroup, CDEnums, CDUtilities (3)
│       ├── selectors/           — CDSelector base + 6 selection strategies (7)
│       ├── spawners/            — CDSpawnContext, CDGridLayout, CDGridRow, CDGridEquation (4)
│       ├── triggers/            — CDTrigger base + 4 trigger types (5)
│       └── visuals/             — CDFaceBinding (1)
├── entity components/
│   ├── brains/
│   │   ├── player/              — 5 player input brains
│   │   ├── ai action/           — 3 AI firing/aiming brains
│   │   └── ai movement/         — 9 AI navigation brains
│   ├── legs/
│   │   ├── directional setters/ — DirectMovementLeg, DirectRotationLeg, GridMovementLeg, GridRotationLeg
│   │   ├── directional adders/  — AccelerationMovementLeg, EngineLeg
│   │   ├── positional setters/  — DirectTargetLeg, TargetRotationLeg
│   │   ├── positional adders/   — AccelerationTargetLeg
│   │   └── other/               — Friction, ScreenWrap, Boomerang, GridDrop, GridAlignment
│   ├── arms/
│   │   ├── collision reactions/ — Damage/Death On Hit/Crash/Joust + Pushback + Score + Status (9)
│   │   ├── death reactions/     — ScoreOnDeathArm, SpawnOnDeathArm (2)
│   │   ├── triggered arms/      — GunArm, TractorBeamArm (2)
│   │   ├── powerup arms/        — PowerupDeliveryArm, PowerupWingmanArm (2)
│   │   └── other/               — PieceSplitterArm (1)
│   ├── guts/
│   │   ├── pools/               — Healthpool, Shieldpool, Resourcepool (3)
│   │   ├── death/               — DieAtZeroHealth, DieOffscreen, DieOnTimer, DieOutOfBounds (4)
│   │   ├── physics/             — DeflectorBounce, ImpulseReceiver, ShapeCollider (3)
│   │   ├── detection/           — LockDetector, VisionCone (2)
│   │   ├── input/               — KBM, MoveAdapter (2)
│   │   └── game logic/          — Announcer, Points, Stun, TSpinDetector, Timer (5)
│   ├── faces/                   — 7 visual components
│   └── voices/                  — 2 audio components
├── game components/
│   ├── cards/                   — 4 UI display components
│   ├── directors/               — 7 stage controllers (legacy, superseded by managers/)
│   ├── managers/                — 3 stage managers (StageManager, StateManager, SignalManager)
│   ├── goals/                   — 2 win/lose conditions
│   ├── marks/                   — 6 spatial triggers
│   ├── projectors/              — 2 visual post-processing
│   ├── speakers/                — 3 audio components
│   └── trapdoors/               — 3 spawners
└── effects/                     — 2 self-destructing visual effects
```

### V2 Implementation Plans

| Plan | Scope | Status | Doc |
|------|-------|--------|-----|
| 19 | Core Infrastructure | ✅ Complete | `planning/19 - V2 Core Infrastructure.md` |
| 19.5 | Object Pooling | ✅ Complete | `planning/19.5 - V2 Object Pooling.md` |
| 20 | Stage (CueCards, Goals, Marks) | ✅ Complete | `planning/20 - V2 Stage.md` |
| 21 | Brains + Legs | ✅ Complete | `planning/21 - V2 Brains + Legs.md` |
| 22 | Arms + Guts | ✅ Complete | `planning/22 - V2 Arms + Guts.md` |
| 23 | Spawners | ✅ Complete | `planning/23 - V2 Spawners.md` |
| 24 | Faces, Voices, Projections & Speakers | ✅ Complete | `planning/24 - V2 Faces, Voices, Projections & Speakers.md` |
| 25 | Swarm Controllers + Galaga | ✅ Complete | `planning/25 - V2 Swarm Controllers + Galaga.md` |
| 26 | Block Drop V2 | ✅ Complete | `planning/26 - Block Drop V2.md` |
| 27 | Blackboard Architecture | ✅ Complete | `planning/27 - V2 Blackboard Architecture.md` |
| 28 | CDStage + CDBody | ✅ Complete | `planning/28 - V2 CDStage + CDBody.md` |

**Full V2 component catalogue:** `memory-bank/07 - Component Catalogue V2.md` (165 scripts written)

---

## Assets

- **Audio:** Procedural synthesis via SoundSynth component (all game audio generated at runtime) + pre-recorded OGG music tracks via MusicPlayer component with floating credit overlays
- **Music:** 4 licensed OGG tracks — 2 public domain (`el_manisero.ogg`, `son_de_la_loma.ogg`) rendered with 8-bit NES soundfont + 2 by Karl Casey / White Bat Audio (`Hunted by Machines.ogg`, `The Devil's Eyes.ogg`) licensed CC-BY 4.0. All with `MusicTrack` attribution resources. MusicPlayer shuffles playlist, fades in/out, shows credits, supports speed ramping.
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT System:** Custom lightweight CRT shader (`Shaders/crt_light.gdshader`) + persistence shader (`Shaders/persistence.gdshader`) + `crt_controller.gd` (self-building Node2D with SubViewport frame accumulation) + PNG overlays (scanlines, phosphor grid, noise). Vector monitor mode uses SubViewport persistence with exponential decay for phosphor trails. Per-game display mode switching via `vector_monitor` export on UGS.
- **Effects:** Self-destructing effect scenes (death_particles, death_broken_triangle_ship) + infinite ScrollingStarsEffect (Galaga-style scrolling star background, configurable density/speed/colors/size)
- **CRT System (V2):** `CRTProjector` game component — full-screen CRT post-processing pipeline ported from V1 `crt_controller.gd`. Identical default parameters. Uses `PROCESS_MODE_ALWAYS` to render during attract mode. Pushes shader params on `_on_initialize()` to avoid dark-screen bug on paused trees.
