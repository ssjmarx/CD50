# Current Status: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-29  
**Engine:** Godot 4.5 (GDScript)  
**Architecture:** V2 Composable Architecture (active development) — V1 archived to `Godot/v1/`  
**Playable Games:** Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop (Modern), Rock Breaker, Bug Drop, Space Bugs, Planetary Attack!, Space Rocks Inverted — ALL componentized, zero game scripts
**In Progress:** V2 Architecture — Plans 19–25 COMPLETE. Plan 26 (Block Drop V2) is next. 155 V2 scripts written.
**Recent Completed:** Plan 25 post-hoc refinements — replaced monolithic SwarmShootingDirector with two data-driven directors: ShootingDirector (CDTrigger + CDSelector) and AimingDirector (per-entity nearest-target aiming). Bug Blaster 2 updated. Plans 19–24 complete as previously documented.
**Demo Status:** Code-locked at 12 games. Only Steam wishlist link remains. Itch.io demo stays on V1 architecture.

**Key Documentation:**
- `USAGE.md` — Complete patterns, anti-patterns, and code quality guide for the V2 architecture
- `memory-bank/05 - Patterns & Anti-Patterns.md` — Quick-reference index for AI agents
- `memory-bank/07 - Component Catalogue V2.md` — Full V2 component inventory (155 scripts)
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
| `cdgame.gd` | `CDGame extends Node2D` | Game root — Dictionary-based bus, state machine, no game logic |
| `cd_entity_component.gd` | `CDComponent2D extends Node2D` | Entity component base — two-phase lifecycle, category priority |
| `cd_game_component.gd` | `CDStageComponent2D extends Node2D` | Stage component base — same lifecycle, no entity ref |
| `cd_collision_buffer.gd` | `CDCollisionBuffer` | Deferred collision flush at Priority 35 |
| `cd_group_registry.gd` | `CDGroupRegistry` | Single source of truth for group counts |
| `cd_collision_matrix.gd` | `CDCollisionMatrix` | Auto-configures physics layers from CDCollisionGroup resources |
| `cd_input_router.gd` | `CDInputRouter` | Pure signal emitter autoload for player input |
| `cd_object_pool.gd` | `CDObjectPool` | Per-type entity pool with acquire/return lifecycle |
| `cd_updater.gd` | `CDUpdater` | Defers state mutations to Priority 90 |
| `cd_effect.gd` | `CDEffect` | Lightweight visual effect base — plays once and auto-frees |
| `cd_sound_bank.gd` | `CDSoundBank` | Centralized audio engine for V2 |
| `cd_enums.gd` | `CDEnums` | Shared enumerations — ComponentCategory, EntityState, GameState, etc. |

---

## V2 Component Count

| Category | Priority | Count | Key Components |
|----------|----------|-------|----------------|
| Core | varies | ~12 | CDEntity, CDGame, CDComponent2D, CDStageComponent2D, CDCollisionBuffer, CDGroupRegistry, etc. |
| Brains (INTENT) | 10 | 16 | PlayerMove/Aim/Action/MoveToBrain, AIChase/Flee/Orbit/Formation/DiveBomb/Aim/RepeatAction/TractorBeam/PathMove/RandomSweep/TimedStep/IdleWanderBrain |
| Legs (STEERING) | 20 | 15 | DirectMovement/Acceleration/Engine/Target/RotationLeg, GridMovement/Rotation/Drop/AlignmentLeg, Friction, ScreenWrap |
| Arms (INTERACTION) | 40 | 16 | DamageOnHit/Crash/Joust, DeathOnHit/Crash/Joust, ScoreOnCollision/Death, Pushback, StatusOnHit, GunArm, SpawnOnDeath, PowerupDelivery/Wingman, TractorBeam, PieceSplitter |
| Guts (STATE) | 50 | 19 | Healthpool/Shieldpool/Resourcepool, DieAtZeroHealth/Offscreen/OnTimer/OutOfBounds, DeflectorBounce/ImpulseReceiver/ShapeCollider, LockDetector/VisionCone, KBM/MoveAdapter, Announcer/Points/Stun/TSpinDetector/Timer |
| Faces (VISUAL) | 60 | 7 | VectorFace, PolygonFace, SpriteFace, VectorEngineFace, VectorThrusterFace, DeathEffectFace, MenacingVectorFace |
| Voices (AUDIO) | 65 | 2 | SoundVoice, ContinuousVoice |
| Stage (RULES) | 70 | 30 | ScoreCard, LivesCard, TimerCard, WaveCard, Goals, Directors, Marks, Speakers, Projectors, Trapdoors |

**Total: ~155 V2 scripts + 41 custom resources**

Full catalogue: `memory-bank/07 - Component Catalogue V2.md`

---

## V2 Architecture (In Progress)

The V2 Composable Architecture is a full refactor of the ECS for the desktop/Steam version. **Canonical reference:** `planning/V2 Rules.md`

### Key Changes from V1

| Aspect | V1 (Current) | V2 (Planned) |
|--------|-------------|--------------|
| Entity base | `UniversalBody` | `CDEntity` — velocity accumulator, entity bus, pool-aware lifecycle |
| Game base | `UniversalGameScript` | `CDGame` — game bus (Dictionary), state machine, no game logic |
| Component base | `UniversalComponent` / `UniversalComponent2D` | `CDComponent2D` — two-phase lifecycle, category priority |
| Signal system | Body routes input→output | Hybrid bus: entity bus (native signals) + game bus (Dictionary) |
| Processing | No fixed ordering | Deterministic priority cascade (5→10→20→30→35→40→50→60→70) |
| Collision | Direct in physics process | `CDCollisionBuffer` flushes at Priority 35 |
| Groups | `group_cache.gd` (lazy dirty flag) | `CDGroupRegistry` — single source of truth, emits `group_count_changed` |
| Spawning | `WaveSpawner` inline | `CDStageSpawner` + `CDObjectPool` — separate acquire/activate |
| Component categories | Brains, Legs, Arms, Components, Rules, Flow | Brains, Legs, Arms, Guts, Faces, Voices, Stage, Speakers, Spawners |
| Collision response | `damage_on_hit`, `die_on_hit` (case-by-case) | 2×2 matrix: DamageOnHit/Crash, DeathOnHit/Crash + Joust variants |
| Internal state | Mixed into Components category | Dedicated **Guts** category (health, timers, resources, lock detection) |

### V2 Directory Structure

```
Godot/Scripts/
├── Core/       — CDEntity, CDGame, CDComponent2D, CDCollisionBuffer, CDGroupRegistry, etc.
├── Brains/     — 14 intent generators (Priority 10)
├── Legs/       — 18 movement executors (Priority 20)
├── Arms/       — 11 world-affecting components (Priority 40)
├── Guts/       — 12 internal state trackers (Priority 50)
├── Faces/      — Visual representation (Priority 60)
├── Voices/     — Entity-level sound
├── Stage/      — Game-level components (Priority 70)
├── Speakers/   — Scene-level sound
├── Spawners/   — Spawn components
└── Resources/  — Custom resources
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
| 26 | Block Drop V2 | � Next | `planning/26 - Block Drop V2.md` |

**Full V2 component catalogue:** `memory-bank/07 - Component Catalogue V2.md` (155 scripts written)

---

## Assets

- **Audio:** Procedural synthesis via SoundSynth component (all game audio generated at runtime) + pre-recorded OGG music tracks via MusicPlayer component with floating credit overlays
- **Music:** 4 licensed OGG tracks — 2 public domain (`el_manisero.ogg`, `son_de_la_loma.ogg`) rendered with 8-bit NES soundfont + 2 by Karl Casey / White Bat Audio (`Hunted by Machines.ogg`, `The Devil's Eyes.ogg`) licensed CC-BY 4.0. All with `MusicTrack` attribution resources. MusicPlayer shuffles playlist, fades in/out, shows credits, supports speed ramping.
- **Fonts:** Kenney retro fonts (Pixel, High, Mini, Rocket, Future, Blocks, Square — regular and narrow variants)
- **CRT System:** Custom lightweight CRT shader (`Shaders/crt_light.gdshader`) + persistence shader (`Shaders/persistence.gdshader`) + `crt_controller.gd` (self-building Node2D with SubViewport frame accumulation) + PNG overlays (scanlines, phosphor grid, noise). Vector monitor mode uses SubViewport persistence with exponential decay for phosphor trails. Per-game display mode switching via `vector_monitor` export on UGS.
- **Effects:** Self-destructing effect scenes (death_particles, death_broken_triangle_ship)
