# CD50 — Editing Conventions & Rules

> **The AI editing quick-reference for this repo.** Rules to follow when editing code + the code-comment standard.
> For the *why* behind these rules, see **`USAGE.md`**. For the catalogue of what exists, see **`memory-bank/PROJECT_STATUS.md`**.

**Companion docs:** `USAGE.md` (architecture deep-dive) · `memory-bank/PROJECT_STATUS.md` (catalogue) · `memory-bank/CURRENT_TASK.md` (active work)

**Tooling:** Aider auto-reads this file; if not, run `aider --read CONVENTIONS.md`.

---

## 1. What the AI may and may not edit

- **Functional code — `.gd` scripts containing game logic, `.tscn` scenes, `project.godot`, and any runtime config — requires explicit permission.** Ask first; never edit on assumption.
- **Freely editable without permission:** documentation (`.md`), `memory-bank/`, `planning/`, and **code comments** inside existing `.gd` files.
- Comments describe existing code only — never hide functional code inside comments, and never comment out dead code (delete it instead).
- When asked to implement a feature the user hasn't approved, don't write the code — explain the pattern, offer 2–3 approaches, and let the user write it.

---

## 2. Mandatory context & reference checks

Before answering substantive questions or editing:

1. Read `memory-bank/PROJECT_STATUS.md` (codebase truth + catalogue) and `memory-bank/CURRENT_TASK.md` (active work). If either looks outdated, **flag it to the user first.**
2. **Before editing any component, read that component's category README in `COMBINED_READMES.md`** (exports, lifecycle hooks, exact signals). `COMBINED_READMES.md` is the per-component authoring reference; this file is only the cross-cutting rules.

---

## 3. Code Comment Convention (mandatory for every `.gd` edit)

1. **All comments start with `##`.** (No `#` line comments, no block comments.)
2. **Each file opens with exactly 3 lines:** the file/class name · what it produces · what it consumes.
3. **Each function has exactly 1 editor description line** — a single `##` line describing its job.
4. **In-function comments only when a block is ≥4 lines *and* not self-documenting.** If the code already reads clearly, don't comment.
5. **File separators only for groups of 3+ related functions.** Don't litter singletons or pairs with dividers.

```gdscript
## cd_example_component.gd
## Produces: a move-intent request from player input.
## Consumes: Godot input events; entity.blackboard["move"].
extends CDEntityComponent

class_name CDExampleComponent

## Reads the move axis each frame and writes a velocity-request key.
func _entity_process(delta: float) -> void:
    ## four-or-more-line, non-obvious block may get one ## comment
    ...
```

---

## 4. Editing decision table

When adding or editing a component, derive these from its kind:

| Component kind | Base class | Category | Priority | Lifecycle hooks to override |
|:---|:---|:---|:---|:---|
| Brain / Leg / Arm / Gut / Face / Voice | `CDEntityComponent` | its category | 10 / 20 / 40 / 50 / 60 / 65 | `_entity_ready`, `_entity_exit`, `_entity_process` |
| Card / Director / Goal / Mark / Speaker / Projector | `CDGameComponent` | `RULES` | 70 | `_game_ready`, `_game_exit`, `_game_process` |
| Manager | `CDGameComponent` | `MANAGER` | 75 | `_game_ready`, `_game_exit`, `_game_process` |
| Spawner | `CDStageTrapdoor` | `RULES` | 70 | override the virtuals only |
| UI card | `CDCueCard` | `RULES` | 70 | `_update_label`, `_publish_tracked`, `_consume_pending` |

**Bus connect / disconnect rules:**
- Subscribe in the `_ready`-phase hook (`_entity_ready` / `_game_ready`); disconnect in the `_exit`-phase hook.
- Use the tracked APIs only: `entity.bus_connect(sig, callable)` / `game.bus_connect(...)`; emit with `entity.bus_emit(sig)` / `game.bus_emit(sig)` / `bus_emit_from(...)`.
- Never use Godot's raw `connect` / `emit` / `call` on these buses.

**Write-before-emit (HARD RULE):** every `bus_emit` / `bus_emit_from` — entity bus *and* game bus — must come **after** the blackboard write the listener will read. Signals are zero-arg; the blackboard is the only payload channel.

```gdscript
## Correct — write data first, then signal
game.blackboard["captured_entity"] = target
game.bus_emit("player_captured")
```

Emitting before writing is a silent, intermittent bug: the connection succeeds and the callback runs, but the data is stale or missing.

---

## 5. Naming & layout

- **Files:** `cd_` prefix, `snake_case` → `cd_example_component.gd`.
- **Classes:** `CD` prefix, `PascalCase` → `CDExampleComponent`. File name matches class name.
- **Placement:** entity behaviors → `Godot/scripts/entity components/<category>/`; game-level → `Godot/scripts/game components/<kind>/`; base classes + infrastructure → `Godot/scripts/core/`; resources → `Godot/scripts/core/resources/<kind>/`.
- **Exports grouped logically** (configuration first, then internal state). Keep comments to the rules in §3 — don't add `# --- Section ---` dividers (they'd violate rule 1).

```
Godot/scripts/
├── core/
│   ├── base classes/         — CDCueCard, CDEntityComponent, CDGameComponent, CDStageTrapdoor
│   ├── infrastructure/       — CDEntity, CDGame, CDBody, CDStage, collision buffer/matrix, group registry, input router, object pool, updater, sound bank
│   └── resources/
│       ├── audio/            — CDNote, CDSoundDef, CDMusicTrack
│       ├── behavior/         — CDTransition, CDScaler, CDScoringRule, CDSequenceStep, CDStageRule
│       ├── curves/           — CDCurve base + shape primitives
│       ├── formation/        — CDFormation, CDMarchingOrder
│       ├── infrastructure/   — CDCollisionGroup, CDEnums, CDUtilities
│       ├── selectors/        — CDSelector base + selection strategies
│       ├── spawners/         — CDSpawnContext, CDGridLayout, CDGridRow, CDGridEquation
│       ├── triggers/         — CDTrigger base + trigger types
│       └── visuals/          — CDFaceBinding
├── entity components/
│   ├── brains/               — player/ + ai action/ + ai movement/
│   ├── legs/                 — directional setters/adders, positional setters/adders, other/
│   ├── arms/                 — collision reactions/, death reactions/, triggered/, powerup/, other/
│   ├── guts/                 — pools/, death/, physics/, detection/, input/, game logic/
│   ├── faces/
│   └── voices/
├── game components/
│   ├── cards/                — cue cards (score, lives, timer, wave, capture)
│   ├── directors/            — aiming, formation, marching order, shooting, stage, swoop
│   ├── managers/             — Stage, State, Signal, Score
│   ├── goals/                — group count, score threshold, signal
│   ├── marks/                — spatial triggers
│   ├── projectors/           — visual post-processing
│   ├── speakers/             — game audio
│   └── trapdoors/            — spawners
└── effects/                  — transient visual effects
```

**Full per-folder counts + the class list:** `memory-bank/PROJECT_STATUS.md` (the catalogue).

---

## 6. Bugs-if-broken rules

These invariants cause silent or intermittent failures when violated. Verify each on every edit:

1. **Write-before-emit** (see §4) — the blackboard write completes before any `bus_emit`.
2. **No direct velocity mutation** — components submit velocity *requests*; the entity merges them. Never assign `entity.velocity = …` in a component.
3. **No cross-component method calls** — emit a signal; let the recipient decide. (Includes poking sibling components via direct references.)
4. **No hardcoded physics layers** — define collision groups via `CDCollisionGroup` resources + the `CDCollisionMatrix`.
5. **`super` first on cleanup** — in `_exit` hooks, call the base cleanup **before** your own, so bus subscriptions and pool state tear down in the correct order.

---

## 7. Priority cascade (reference)

```
REGISTRY(5) → INPUT(8) → BRAINS(10) → LEGS(20) → ENTITY(30) → COLLISION(35) → ARMS(40) → GUTS(50) → FACES(60) → VOICES(65) → STAGE(70) → MANAGER(75) → UPDATE(90)
```

Reserved for infrastructure (never set by a component): **REGISTRY, INPUT, ENTITY, COLLISION, UPDATE.**

| Category | Priority | Purpose |
|:---|:---|:---|
| Brains (INTENT) | 10 | Input / AI — pure intent generators, never touch velocity |
| Legs (STEERING) | 20 | Movement executors — consume intent, submit velocity requests |
| Arms (INTERACTION) | 40 | World-affecting — collision response, scoring, spawning |
| Guts (STATE) | 50 | Internal state trackers — health, timers, resources, detection |
| Faces (VISUAL) | 60 | Visual representation — drawing code only |
| Voices (AUDIO) | 65 | Entity-level audio |
| Stage (RULES) | 70 | Game-level — cards, goals, marks, directors, trapdoors, speakers, projectors |
| Managers | 75 | Stage lifecycle & accumulated state |

> **Director vs Manager boundary:** both live in `game components/`. **Directors** (`RULES`/70) orchestrate across groups *each frame* — they gather entities, evaluate data-driven rules, and push intent onto blackboards/signals (aiming, formation, marching order, shooting, swoop) or perform one-shot swaps (stage). **Managers** (`MANAGER`/75) own lifecycle & accumulated state — staging entities in/out (StageManager), transitioning entities between groups as state (StateManager), running timed signal sequences (SignalManager), evaluating scoring rules (ScoreManager). Rule of thumb: *if it pushes intent onto entities every frame, it's a director; if it reacts to triggers to change what's active or accumulated, it's a manager.*

---

## 8. Base classes (reference)

| Class | Extends | Role |
|:---|:---|:---|
| `CDEntity` | `CharacterBody2D` | Blank physics shell — velocity accumulator, entity bus, blackboard, pool-aware lifecycle |
| `CDGame` | `Node2D` | Game root — game bus + blackboard, state machine, no game logic |
| `CDEntityComponent` | `Node2D` | Entity component base — two-phase lifecycle, category priority |
| `CDGameComponent` | `Node2D` | Game-level component base — same lifecycle, no entity ref, cached `game` |
| `CDBody` | `Node2D` | Behavior-set container inside an entity — sleeps/wakes on signals |
| `CDStage` | `Node2D` | Scene container — sleeps/wakes on signals; holds trapdoors/directors |

Signal system: both buses use **native Godot signals** via `bus_connect()` / `bus_emit()`. All dynamic signals are **zero-arg**; data flows through `entity.blackboard` and `game.blackboard`. The buses auto-populate `"position"`, `"rotation"`, `"velocity"` each frame and track the current emitter in `_signal_emitters` (enables `CDSelectSignalEmitter`).

---

## 9. Memory-bank maintenance (condensed)

Two files only. **`PROJECT_STATUS.md`** = *what the code IS* — update when a script is added/removed/renamed, a new pattern or anti-pattern emerges, or the architecture shifts (keep the catalogue + count current). **`CURRENT_TASK.md`** = *what we're DOING* — update when the active task, a milestone, ship status, or roadmap changes. Don't update either for uncommitted WIP or opinion/discussion. When unsure: *state* → `PROJECT_STATUS.md`, *activity* → `CURRENT_TASK.md`.