# USAGE — The CD50 Architecture

> **The deep guide: how the V2 composable architecture works, and how every component category fits together.**
> For a list of what exists, see `memory-bank/PROJECT_STATUS.md`.
> For editing rules, see `CONVENTIONS.md`.
> For per-component authoring detail, see `COMBINED_READMES.md`.

---

## 1. Introduction

CD50's V2 architecture has one goal: **build every game from generic, reusable components — zero game-specific scripts.**

A game here is not a script. A game is a *scene*: a `CDGame` root with an infrastructure layer, a set of `CDStage` nodes holding the per-level content, and a player entity. Every behavior in that game — movement, shooting, health, AI, scoring, spawning, audio, visuals — comes from composing small, single-purpose components onto blank entity shells or onto the game root. The components never know which game they're in. They only know their category, their priority, the signals they emit/listen to, and the blackboard keys they read/write.

This document explains the runtime that makes that possible, then walks through how the categories collaborate to produce real gameplay. The running example throughout is **Bug Blaster 2**, the first complete V2 game (a Galaga-style remake with capture/rescue and five levels). Where you see scene snippets, they're drawn from the actual shipped scenes `Godot/games/bug_blaster_2.tscn` and `Godot/entities/player/bug_blaster_2_player.tscn`.

### How to read this doc set
- **`README.md`** — front door + quick start.
- **`USAGE.md`** *(this file)* — the *why* and *how* of the architecture.
- **`CONVENTIONS.md`** — the *rules* for editing code.
- **`memory-bank/PROJECT_STATUS.md`** — the *catalogue* of what exists.
- **`COMBINED_READMES.md`** — per-category authoring reference.

---

## 2. The Core Runtime

### 2.1 `CDEntity` — the blank shell

Every thing that moves or reacts in a game is a `CDEntity`. It is a `CharacterBody2D`, but it contains **no game logic**. It provides:

- **A velocity accumulator.** Components never set `velocity` directly. They submit velocity *requests*; the entity merges them (intent → steering → impulses) and applies the final velocity once in the entity slot of the priority cascade.
- **An entity bus** — a per-entity signal bus (see §3).
- **A blackboard** — a per-entity `Dictionary` for ad-hoc state.
- **A pool-aware lifecycle** — activate/deactivate hooks instead of spawn/free, so entities can be recycled by the `CDObjectPool`.
- **A group membership** — it registers itself with the `CDGroupRegistry` under one or more `StringName` groups.

You build an entity by giving it a `Face` (appearance) and a `Leg` (movement), then adding whatever `Brain`/`Arm`/`Gut`/`Voice` components it needs. Generic entities live in `Godot/entities/generic/`; player and nonplayer variants instance them and add the appropriate components.

### 2.2 `CDGame` — the root

`CDGame` is a `Node2D` and the scene root of every game. It provides:

- **A game bus** — the global signal bus (see §3).
- **A blackboard** — the global `Dictionary`.
- **A state machine** — `BOOT → ATTRACT → PLAYING → GAME_OVER → …`, driven by signals from goals/cards. It holds **no game logic**; transitions are data-driven by the components beneath it.
- **`game_bounds`** — a `Rect2` (commonly `Rect2(0, 0, 640, 360)`) used by trapdoors, marks, wrap legs, and bounds-death guts.
- **Resolution helper** — `find_ancestor()` lets any node walk up to its owning `CDGame`.

A typical game scene tree:

```
BugBlaster2 (CDGame)
├── Infrastructure/
│   ├── CDCollisionBuffer
│   ├── CDCollisionMatrix
│   ├── CDGroupRegistry
│   ├── CDInputRouter
│   ├── CDUpdater
│   ├── CDSoundBank
│   └── CRTProjector
├── AI Stuff/                      ← directors, marks (game-level RULES components)
│   ├── FormationDirector
│   ├── StateManager
│   ├── ShootingDirector
│   └── TractorMark / TimedMark
└── Stages/                        ← CDStage nodes
    ├── Level1Stage/
    │   ├── PointTrapdoor × 4
    │   ├── SwoopDirector × 4
    │   └── SignalManager
    ├── Level2Stage/ … Level5Stage
```

### 2.3 Infrastructure singletons

These are the services the components rely on. They live under `Infrastructure/` and run at reserved priority slots.

| Service | Role | Reserved slot |
|:---|:---|:---|
| `CDGroupRegistry` | Authoritative list of active entities per group. The only thing allowed to answer "who is in group X?". Queries: union, nearest-N, count. | REGISTRY (5) |
| `CDInputRouter` | Routes raw Godot input to the currently focused entity's brains. | INPUT (8) |
| `CDCollisionBuffer` | Collects per-frame collision intents and resolves them into physics events (who hit whom, with what intent). | COLLISION (35) |
| `CDCollisionMatrix` | Data-driven rules: which named groups collide with which. Configured via `CDCollisionGroup` resources. | — |
| `CDObjectPool` | Recycles entities and components. Activate/deactivate, not free/instantiate, during gameplay. | — |
| `CDUpdater` | Deferred-work queue. Flushes transitions and other "after this frame" work so the current frame stays consistent. | UPDATE (90) |
| `CDSoundBank` | Procedural audio engine; voices and speakers request playback here. | — |

---

## 3. The Two Buses & The Blackboard

This is the heart of the architecture. Components never call methods on each other. They communicate through **two signal buses** and **two blackboards**.

### 3.1 The two buses

- **Entity bus** — scoped to one entity. Use for anything internal to that entity: `"fire"`, `"thrust"`, `"player_captured"`, `"leader_destroyed"`. Connect with `entity.bus_connect(sig, callable)`; emit with `entity.bus_emit(sig)`.
- **Game bus** — scoped to the whole game. Use for cross-entity / global events: `"game_play"`, `"level_one_complete"`, `"player_captured"` (when the whole game needs to know). Connect with `game.bus_connect(...)`; emit with `game.bus_emit(...)`.

A signal often travels **both** buses deliberately. In Bug Blaster 2, `player_captured` is emitted on the *target entity's bus* (so that entity's `CapturedBody` can wake) **and** on the *game bus* (so the `StateManager` can move the entity from the `players` group to the `enemies` group). This dual emission is the standard pattern for events that are both personal and systemic.

### 3.2 Zero-arg signals + blackboard payloads

**Signals carry no arguments.** Always. If a component needs to pass data with an event, it writes to the blackboard *first*, then emits. This keeps signal signatures stable and lets any component participate without knowing each other's types.

```
## WRONG — signals with args
target.bus_emit("captured_by", self)

## RIGHT — write, then emit
target.blackboard["captured_by"] = self
target.bus_emit("player_captured")
```

### 3.3 The write-before-emit hard rule

Because of §3.2, this rule is inviolable: **the blackboard write must complete before the emit.** Listeners fire synchronously on emit; if the data isn't there yet, they'll read stale or missing values. This is the #1 source of subtle bugs. When you emit, ask: "is every key a listener might read already written?"

### 3.4 `bus_emit_from` and emitter tracking

Some selectors (notably `CDSelectSignalEmitter`) need to know *which* entity emitted a signal this frame. The bus tracks the current emitter for this purpose. Use the tracked-emit helpers (`_publish_tracked` / `bus_emit_from`) when you need a game-bus signal to be attributable to a specific entity.

---

## 4. The Priority Pipeline

Components in the same category all run at the same priority. Within a category, order is the component's own processing order. The cascade guarantees that intent is generated before it's consumed, collisions are resolved before reactions, and reactions complete before visuals/audio update.

```
REGISTRY(5)  → groups rebuilt for this frame
INPUT(8)     → input routed to focused entity
BRAINS(10)   → intent generated (move direction, fire, thrust)
LEGS(20)     → intent consumed → velocity requests submitted
ENTITY(30)   → velocity requests merged → move_and_slide()
COLLISION(35)→ collision buffer resolves hits into events
ARMS(40)     → collision/death events → reactions (damage, score, spawn, capture)
GUTS(50)     → state updated (health, timers, detection)
FACES(60)    → visuals redrawn from final state
VOICES(65)   → entity audio triggered
STAGE(70)    → game-level rules: cards, goals, directors, marks, trapdoors
MANAGER(75)  → lifecycle: stage transitions, signal sequences, score application
UPDATE(90)   → deferred work flushed (transitions, pool returns)
```

**Reserved slots** (never set by a component): `REGISTRY`, `INPUT`, `ENTITY`, `COLLISION`, `UPDATE`.

**Why it matters:** Because brains run before legs, a brain can write `"move"` to the blackboard and trust that the leg will read it this same frame. Because arms run after collision, an arm reacts to a hit that actually happened. Because managers run after everything, a `StageManager` rule that fires on a goal signal knows the frame's gameplay is settled. If you ever find yourself reaching for `call_deferred`, check first whether the cascade already orders things for you.

---

## 5. Component Categories

| Category | Priority | Role | Typical consumes | Typical emits |
|:---|:---|:---|:---|:---|
| **Brains** | 10 | Intent. Input or AI. Pure — never touch velocity. | input, blackboard | entity-bus intents (`"move"`, `"fire"`) |
| **Legs** | 20 | Steering. Turn intent into velocity requests. | intent keys | velocity requests |
| **Arms** | 40 | Interaction. Change the world or other entities. | collision/death events | damage, score, spawns, capture |
| **Guts** | 50 | State. Health, timers, resources, detection. | blackboard, time | death, status, detection signals |
| **Faces** | 60 | Visual. Drawing only — no gameplay state. | blackboard, transforms | (nothing; they draw) |
| **Voices** | 65 | Entity audio. | entity-bus signals | sound requests to `CDSoundBank` |
| **Stage** (game) | 70 | Rules. Cards, goals, directors, marks, trapdoors, speakers, projectors. | game bus, registry | game-bus signals, blackboard writes |
| **Managers** (game) | 75 | Lifecycle & accumulated state. | trigger/selector resources | stage sleep/wake, group transitions, scoring |

### 5.1 The Director vs Manager boundary

Both live in `game components/`, and the line between them is deliberate:

- **Directors** (`RULES`/70) **orchestrate across groups each frame.** They gather entities from the registry, evaluate data-driven resources (triggers, selectors, scalers, curves, formations), and push results onto blackboards or fire signals. They are *frame-active*. Examples: `FormationDirector` writes `move_direction` to every formation member; `ShootingDirector` picks N random shooters and fires their entity-bus shoot signal; `SwoopDirector` drives entities along a `CDCurve` and emits `swoop_complete`.
- **Managers** (`MANAGER`/75) **own lifecycle and accumulated state.** They react to triggers but don't run continuous per-frame logic. They stage entities in/out, run timed signal sequences, apply scoring, and transition entities between groups. Examples: `StageManager` sleeps/wakes `CDStage` nodes; `SignalManager` runs a `CDSequenceStep` list; `StateManager` moves entities between groups (deferred via `CDUpdater`); `ScoreManager` applies `CDScoringRule` deltas.

Rule of thumb: *if it pushes intent onto entities every frame, it's a director; if it reacts to triggers to change what's active or accumulated, it's a manager.*

---

## 6. How They Work Together

This is the section the rest of the doc exists to support: the end-to-end flows that show all categories collaborating.

### 6.1 Intent → Motion

The simplest full loop. A `PlayerMoveBrain` reads input (priority 10) and writes `blackboard["move"] = Vector2(...)`. The entity's `DirectMovementLeg` (priority 20) reads that key and submits a velocity request. At `ENTITY` (30) the entity merges requests and calls `move_and_slide()`. The `Face` (60) redraws to match. No component knows about any other.

```
input ─► PlayerMoveBrain ──write "move"──► blackboard
                                              │
                       DirectMovementLeg ◄──read──┘
                              │
                       velocity request ─► entity (merges, moves)
                              │
                       VectorFace ◄── redraws
```

### 6.2 Collision → Reaction → State

1. The `CDCollisionBuffer` (35) resolves overlaps into hit events using the `CDCollisionMatrix`'s group rules (e.g. `"player_bullets"` collides with `"enemies"`).
2. `Arms` (40) react. `DeathOnHitArm` emits `"entity_deactivating"` on the entity bus; `ScoreOnCollisionArm` writes to the blackboard and emits a scoring signal.
3. `Guts` (50) update state. `HealthpoolGuts` decrements health; if zero, `DieAtZeroHealthGuts` emits the death signal.
4. Because arms run *after* collision and *before* guts/state, by the time the managers evaluate goals at 70–75, the frame's damage and deaths are settled.

### 6.3 The death lifecycle (pool-aware)

Entities aren't freed — they're deactivated and returned to the `CDObjectPool`. The death flow:

1. A death condition fires (`DieAtZeroHealthGuts`, `DieOffscreenGuts`, etc.) → emits `"entity_deactivating"` on the entity bus.
2. Listeners react **while the entity is still active**: `SpawnOnDeathArm` spawns debris, `ScoreOnDeathArm` awards points, `DeathEffectFace` spawns a particle effect, a `SoundVoice` plays.
3. The entity deactivates: removes itself from the `CDGroupRegistry`, sleeps its components, and returns to the pool.
4. `CDUpdater` (90) flushes any deferred work (e.g. group transitions that depended on this entity being gone).

This ordering — *emit first, while active, then deactivate* — is why death reactions work reliably. Never deactivate before the death signal is emitted.

### 6.4 Spawning into the pool

Spawners (`CDStageTrapdoor` subclasses: `PointTrapdoor`, `EdgeTrapdoor`, `GridTrapdoor`) don't instantiate entities mid-game. They request recycled instances from the pool, configure them, and activate them. Each trapdoor:

- Listens for one or more trigger signals (e.g. `"spawn_top_left"`).
- Reads a `CDSpawnContext` resource for extra groups + rotation to apply.
- Applies a `spawn_count_equation` and optional `stagger_delay`.
- Emits `on_spawning_complete` signals when done (which downstream directors wait on).

In Bug Blaster 2's `Level1Stage`, four `PointTrapdoor`s fire on `"spawn_top_left"`, `"spawn_top_right"`, `"spawn_bottom_left"`, `"spawn_bottom_right"`, each emitting its own `spawning_complete_*` signal that arms the matching `SwoopDirector`.

### 6.5 Group orchestration: directors + selectors + triggers

The data-driven triad that controls enemy behavior:

- A **trigger** (`CDSignalTrigger`, `CDTimerTrigger`, `CDGroupCountTrigger`, or `CDCompositeTrigger`) decides *when*.
- A **selector** (`CDSelectAll`, `CDSelectRandomN`, `CDSelectNearestN`, `CDSelectSignalEmitter`, …) decides *who*.
- A **director** applies the *what*: writes blackboard intent, fires entity-bus signals, or performs swaps.

Example from Bug Blaster 2's `StateManager`: a `CDTransition` moves entities from `"formation"` to `"diving"` on a `CDTimerTrigger` (every ~6s ±1s) selecting `CDSelectRandomN`, and emits `"begin_dive"` on each target's entity bus. The `AISwoopBrain` on those entities wakes and follows a `CDCurve`.

### 6.6 State machine & `CDStage` sleep/wake

Groups double as states: an entity in `"formation"` behaves differently from one in `"diving"`. `CDTransition` resources (run by `StateManager`) move entities between groups, and the components on those entities gate on group membership or on wake/sleep signals.

The same pattern scales up to whole scenes via `CDStage`. A `CDStage` is a container that sleeps/wakes on signals and holds a level's worth of trapdoors, directors, and sequences. `StageManager` drives them with `CDStageRule` resources:

```
"level_one_complete" + (enemies == 0)  ─►  sleep Level1Stage, wake Level2Stage
"level_two_complete" + (enemies == 0)  ─►  sleep Level2Stage, wake Level3Stage
...
"level_five_complete" + (enemies == 0) ─►  sleep Level5Stage, wake Level1Stage (loop)
```

The `CDCompositeTrigger` (AND) ensures a level only advances when *both* its completion signal fires *and* the screen is clear — no half-finished transitions.

### 6.7 The "fat player" / behavior-set pattern (`CDBody`)

`CDBody` is a container *inside* an entity that holds its own components and sleeps/wakes on signals. By giving one entity several `CDBody` children, you get a state machine of behavior sets without any code.

Bug Blaster 2's player has three:

| Body | Wake on | Sleep on | Contains |
|:---|:---|:---|:---|
| `ActiveBody` (default) | `"escort_achieved"` | `"player_captured"` | `PlayerMoveBrain`, `PlayerActionBrain` |
| `CapturedBody` | `"player_captured"` | `"leader_destroyed"` | `LeaderTrackerGuts`, `AIEscortBrain`, `HealthpoolGuts`, `LeaderTeleportLeg` |
| `RescuedBody` | `"leader_destroyed"` | `"escort_achieved"` | `AIEscortBrain` (follows active player), `HealthpoolGuts` |

The capture/rescue cycle: spider's `TractorBeamArm` writes `target.blackboard["captured_by"]` and emits `"player_captured"` on both buses → `ActiveBody` sleeps, `CapturedBody` wakes (player now escorts the spider via `AIEscortBrain`) → spider dies → `LeaderTrackerGuts` emits `"leader_destroyed"` → `CapturedBody` sleeps, `RescuedBody` wakes (player descends to formation) → `"escort_achieved"` → `ActiveBody` wakes, now with a wingman.

**All of this is wired in the `.tscn` — there is no capture script.** It's the purest expression of the architecture's goal.

### 6.8 Scoring → manager → card → blackboard

Scoring is fully decoupled. An `Arm` (`ScoreOnCollisionArm`, `ScoreOnDeathArm`) writes a delta and emits a scoring signal. `ScoreManager` (75) evaluates `CDScoringRule` resources — each rule binds a trigger to a score delta and an optional multiplier delta — and applies the result to `game.blackboard["score"]` / `["multiplier"]`. The `ScoreCard` (70) listens and updates its label. The `ScoreThresholdGoal` watches the same blackboard key for a win condition. No component knows where the score came from or where it's going.

### 6.9 The win/lose fire contract

Goals are the *only* components allowed to fire win/lose signals (`"game_won"` / `"game_lost"`). They evaluate a condition — a group count (`GroupCountGoal`), a blackboard threshold (`ScoreThresholdGoal`), or a signal (`SignalGoal`) — and fire on the game bus. `CDGame`'s state machine reacts and transitions (e.g. `PLAYING → GAME_OVER`). This centralizes the win/lose decision so it can't be fired accidentally by an arm or gut.

### 6.10 Spatial marks

`CDMark` and its subclasses are `Area2D`-based spatial triggers. They filter by group and, when a qualifying body enters/exits/stays, they write to blackboards and emit on the game bus, the entity bus, or both. Bug Blaster 2 uses a `TractorMark` positioned at capture height: when a `"diving"` spider enters, it emits `"fire_tractor_beam"` on that spider's entity bus, which the spider's `AITractorBeamBrain` listens for. Marks bridge *space* into the signal architecture.

### 6.11 Audio & visual layering

Audio and visuals are layered symmetrically at two scopes:

- **Entity level:** `Faces` (60) draw; `Voices` (65) play one-shot or continuous synthesized sound via `CDSoundBank`.
- **Game level:** `Projectors` (CRT, credits) and `Speakers` (music, ambient continuous, one-shot) handle the cabinet-level presentation.

All sound is either **procedurally synthesized** (`CDSoundBank` driven by `CDNote`/`CDSoundDef` resources) or **streamed music** (`CDMusicTrack` via `MusicSpeaker`). No raw audio files for SFX — this keeps the asset footprint tiny and lets sounds be data-edited.

---

## 7. Data Resources — configuring without code

A huge amount of behavior is authored as **resources in the inspector**, not as code. The categories:

- **Triggers** (`core/resources/triggers/`) — *when*. `CDSignalTrigger`, `CDTimerTrigger`, `CDGroupCountTrigger`, `CDCompositeTrigger`.
- **Selectors** (`core/resources/selectors/`) — *who*. `CDSelectAll`, `CDSelectRandomN`, `CDSelectNearestN`, `CDSelectNearestNToGroup`, `CDSelectByKey`, `CDSelectSignalEmitter`.
- **Scalers** (`core/resources/behavior/`) — *how much*, varying by wave/group count. `CDWaveScaler`, `CDGroupCountScaler`.
- **Curves** (`core/resources/curves/`) — *what path*. 12 shape primitives + `CDSequenceCurve` to chain them.
- **Formations** (`core/resources/formation/`) — *what grid + how it marches*. `CDFormation` + `CDMarchingOrder` steps.
- **Shapes / Spawn Contexts** (`core/resources/spawners/`) — *how to lay out & tag spawns*.
- **Sound** (`core/resources/audio/`) — *what it sounds like*. `CDNote` → `CDSoundDef` → voices/speakers.
- **Rules** (`core/resources/behavior/`) — *what the managers run*. `CDScoringRule`, `CDStageRule`, `CDTransition`, `CDSequenceStep`.

When you want a new behavior, **reach for a resource before a script.** Want enemies to dive every 5 seconds instead of 6? Edit the `CDTimerTrigger.interval`. Want a sine dive instead of a parabola? Swap the `CDCurve` resource on the `SwoopDirector`. New scoring rule? Add a `CDScoringRule` to the `ScoreManager`. This is the architecture's payoff: most "design changes" are inspector edits.

---

## 8. Sleep/Wake & Object Pooling

### 8.1 `CDBody` and `CDStage`

Both containers share the same sleep/wake model:

- `start_asleep` — begin inactive.
- `wake_on` / `sleep_on` — `Array[StringName]` of signals that toggle activity.
- `on_wake_signal` (`CDStage`) — a single signal that gates waking (e.g. Bug Blaster 2's level stages all wake on `"level_start"`).

When asleep, a container's components don't process and its children aren't active in physics. This is how a game holds five levels' worth of content but only runs one at a time.

### 8.2 The deferred flush

Some operations (group transitions, pool returns) must happen *after* the current frame's logic to avoid mutating collections mid-iteration. `CDUpdater` (90) is the deferred-work queue. `StateManager`, for example, schedules transitions through it. If you write a manager that needs to change groups or stages in reaction to a mid-frame event, queue it for the updater flush rather than doing it inline.

---

## 9. Worked Example — Bug Blaster 2, End to End

This ties every system above together. Bug Blaster 2 is a Galaga-style game: enemies spawn in from the edges, swoop to a formation, dive at the player, some attempt capture, and the player progresses through five looping levels.

### 9.1 Boot & attract

`CDGame` starts in `ATTRACT`. `CRTProjector` overlays the CRT effect. `MusicSpeaker` plays the playlist. On coin/start, `"game_play"` fires and the state machine enters `PLAYING`.

### 9.2 Level 1 spawns

`StageManager` has a `CDStageRule` that wakes `Level1Stage` on `"level_start"` (fired by a `SignalManager` sequence triggered by `"game_play"`). Inside `Level1Stage`:

- A `SignalManager` runs a `CDSequenceStep` list: emit `"ambience"`, then `"spawn_top_left"`, `"spawn_top_right"`, `"spawn_bottom_left"`, `"spawn_bottom_right"` with staggered delays.
- Four `PointTrapdoor`s react to those signals, pull entities from the pool (tagged with `CDSpawnContext` groups like `&"swooping"` + `&"left"`), and emit `spawning_complete_*` when done.
- Four `SwoopDirector`s, each waiting on its `spawning_complete_*` signal, drive those entities along a `CDCurve` (parabola + sine, chained via `CDSequenceCurve`) toward a formation target, emitting `swoop_complete`.

### 9.3 Formation & marching

Once swooped in, a `StateManager` `CDTransition` (triggered by `swoop_complete`, selecting the signal emitter) moves entities from `"swooping"` to `"formation"`. The `FormationDirector` now owns them: it lays out three `CDFormation` grids (bosses / lieutenants / grunts) and marches them through a `CDMarchingOrder` sequence (step, breathe, step) with speed scaled by a `CDWaveScaler`.

### 9.4 Diving & shooting

Periodically, a `CDTransition` on a `CDTimerTrigger` + `CDSelectRandomN` moves some enemies from `"formation"` to `"diving"` and emits `"begin_dive"` on their entity bus; their `AISwoopBrain` takes over. Meanwhile a `ShootingDirector` (triggered by its own timer, selecting `CDSelectNearestNToGroup`) fires `"fire"` on random bugs/wasps' entity buses; their `GunArm` spawns `enemy_bullets`.

### 9.5 Capture & rescue (the "fat player")

When a diving spider enters the `TractorMark`, it emits `"fire_tractor_beam"` on the spider's entity bus. The spider's `AITractorBeamBrain` qualifies (it's in `"diving"`) and arms its `TractorBeamArm`. The arm runs an overlap query; on hit it writes `target.blackboard["captured_by"]` and emits `"player_captured"` on **both** the target's entity bus and the game bus.

Now the player's `CDBody` state machine (§6.7) takes over: `ActiveBody` sleeps, `CapturedBody` wakes and escorts the spider. The `StateManager` simultaneously moves the player from `"players"` to `"enemies"` (so it can be shot!). When the spider is destroyed, `LeaderTrackerGuts` emits `"leader_destroyed"` → `RescuedBody` wakes → the player descends to wingman position → `"escort_achieved"` → `ActiveBody` wakes with dual-ship firing. `SoundVoice` components play captured/rescued jingles throughout; `AnnouncerGuts` relays signals across buses.

### 9.6 Level advance & loop

Each level's `SignalManager` sequence ends by emitting `level_N_complete`. The `StageManager`'s `CDStageRule`s — gated by a `CDCompositeTrigger` requiring *both* the completion signal *and* `CDGroupCountTrigger(enemies == 0)` — sleep the current stage and wake the next. After Level 5, a rule loops back to Level 1. Each cycle, the `WaveCard` increments and the `CDWaveScaler` ramps speed, so the loop gets harder.

### 9.7 Win, lose, score

The `ScoreCard`/`ScoreManager`/`ScoreThresholdGoal` chain handles scoring (§6.8). The `LivesCard` tracks deaths; when depleted it fires the lose condition. Goals fire `"game_won"`/`"game_lost"` (§6.9) and `CDGame` transitions to `GAME_OVER`.

---

## 10. Conventions & Anti-patterns

### Do
- Compose small, single-purpose components.
- Communicate via signals + blackboard only.
- Write the blackboard **before** you emit.
- Pick the right base class and category priority for your component.
- Prefer a data resource (trigger/selector/curve/scaler) over a new script.
- Gate behavior on group membership or wake/sleep signals.

### Don't
- **Don't call methods across components.** Emit a signal.
- **Don't mutate `velocity` directly.** Submit a velocity request.
- **Don't hardcode physics layers.** Use `CDCollisionGroup` resources + the matrix.
- **Don't emit signals with arguments.** Write to the blackboard, then emit zero-arg.
- **Don't create game-specific scripts.** If your component only makes sense in one game, it's too specific — generalize it or express the difference as data.
- **Don't free entities mid-game.** Deactivate and return to the pool.
- **Don't fire win/lose from anywhere but a Goal.**

See `CONVENTIONS.md` for the full editing rules and code-comment standards.

---

## 11. Component Reference Index

For per-component authoring detail (exports, lifecycle hooks, exact signals), jump to the relevant section of `COMBINED_READMES.md`:

| Want to know about… | Read the `COMBINED_READMES.md` section |
|:---|:---|
| Base classes & lifecycle | `cd_entity_component`, `cd_game_component`, `cd_cue_card`, `cd_stage_trapdoor` |
| Infrastructure | `cd_entity`, `cd_game`, `cd_body`, `cd_stage`, `cd_collision_buffer`, `cd_group_registry`, `cd_object_pool`, `cd_updater`, `cd_sound_bank` |
| Brains | `brains/` |
| Legs | `legs/` |
| Arms | `arms/` |
| Guts | `guts/` |
| Faces | `faces/` |
| Voices | `voices/` |
| Cards / Goals / Marks | `cards/`, `goals/`, `marks/` |
| Directors | `directors/` |
| Managers | `managers/` |
| Trapdoors | `trapdoors/` |
| Speakers / Projectors | `speakers/`, `projectors/` |
| Resources (triggers, selectors, curves, formations, scalers, audio) | `core/resources/...` |

For the full list of what exists right now, see `memory-bank/PROJECT_STATUS.md`.