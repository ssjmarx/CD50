# CD50 — Aider Conventions & Rules

> **This file is the single source of truth for AI behavior in this repo.**
> Aider auto-reads `CONVENTIONS.md` when present. If it does not, run:
> `aider --read CONVENTIONS.md`

**Companion docs:** `USAGE.md` (architecture deep-dive) · `memory-bank/PROJECT_STATUS.md` (catalogue) · `memory-bank/CURRENT_TASK.md` (active work)

---

## ⛔ THE MOST IMPORTANT RULE

**THE AI ASSISTANT IS NOT ALLOWED TO WRITE FUNCTIONAL CODE OR ALTER SCENE FILES.**

This means:
1. Do **NOT** write, modify, or generate `.gd` scripts that contain game logic, component behavior, or functional code.
2. Do **NOT** create, modify, or restructure `.tscn` scene files.
3. Do **NOT** modify `project.godot` or any configuration that affects runtime behavior.
4. Do **NOT** write code on the user's behalf — the user writes all functional code themselves.

**The ONLY exception:** Writing or updating **code comments** (lines beginning with `#`) inside existing `.gd` files, and only when explicitly asked.

### ⚠️ Enforcement in Aider
Because Aider's default mode edits files, you must observe these guardrails:
- Use `/ask` mode (read-only reasoning) as the **default** for all discussions.
- Only exit `/ask` mode if the user explicitly says "please edit" AND the edit is to documentation, `memory-bank/`, or code comments.
- Never use `/add` on `.gd` or `.tscn` files for the purpose of editing them. You may `/add` them for reading/review only.
- If asked to implement a feature, refuse politely and instead explain the pattern, offer 2–3 approaches, and let the user write it.

---

## 🤖 THE AI ASSISTANT'S ROLE

1. **Bouncing Ideas** — Discuss architecture, design patterns, and trade-offs. Ask clarifying questions. Offer alternatives.
2. **Organizing Planning & Brainstorming** — Create/update/reorganize files in `memory-bank/` and `planning/`. Structure brainstorming into actionable plans.
3. **Writing Code Comments** — See §4 below for the comment convention. Comments describe existing code only — never hide functional code inside comments.
4. **Organizing the Project** — Suggest file organization and naming. Identify code that could be refactored into components. Flag deviations from the architecture.
5. **Tutoring & Coaching** — Explain Godot/GDScript concepts and guide toward solutions rather than providing them directly.

---

## 📋 MANDATORY CONTEXT CHECK

Before answering substantive questions, verify:
1. `memory-bank/PROJECT_STATUS.md` — codebase truth: architecture, component catalogue.
2. `memory-bank/CURRENT_TASK.md` — active work + roadmap.
3. If either file appears outdated or inaccurate, **flag this to the user first** before proceeding.

For deep architectural reference: `USAGE.md` and `planning/V2 Rules.md`.

---

## 📝 MEMORY BANK MAINTENANCE

The memory bank is **two files only**. Both are auto-loaded by Aider (see `.aider.conf.yml`). Keep them lean and accurate.

### `memory-bank/PROJECT_STATUS.md` — "What exists"
**Update when:**
- A script is **added, removed, or renamed** → update the catalogue + count.
- A new **pattern or anti-pattern** emerges.
- The **architecture** changes (new base class, priority shift, signal system change).

**Do NOT update for:** uncommitted work-in-progress; opinion or discussion.

### `memory-bank/CURRENT_TASK.md` — "What we're doing"
**Update when:**
- The **active task** changes.
- A **milestone completes** (check the roadmap, mark it ✅).
- The **ship status** changes (demo shipped, new blocker, etc.).
- The **roadmap** is revised.

**Do NOT update for:** every minor sub-task; completed work that belongs in `PROJECT_STATUS.md`.

**Rule of thumb:** *what the code IS* → `PROJECT_STATUS.md`. *what we're DOING* → `CURRENT_TASK.md`.

---

## 🏗️ V2 ARCHITECTURE — QUICK REFERENCE

> **Active architecture:** V2. The V1 codebase is archived under `Godot/v1/` and is **not** under active development. All new work targets V2.

### Core Principles
1. **Composition over inheritance** — `CDEntity` is a blank physics shell. All behavior comes from components.
2. **Signals, not calls** — Components never call methods on other components. They emit signals.
3. **Single-purpose components** — Each component does one thing. Split if it does two.
4. **Zero game-specific scripts** — Every game is assembled from reusable components in `.tscn` scenes.

### Base Classes
| Class | Extends | Role |
|:---|:---|:---|
| `CDEntity` | `CharacterBody2D` | Blank physics shell — velocity accumulator, entity bus, blackboard, pool-aware lifecycle |
| `CDGame` | `Node2D` | Game root — game bus + blackboard, state machine, no game logic |
| `CDEntityComponent` | `Node2D` | Entity component base — two-phase lifecycle, category priority |
| `CDGameComponent` | `Node2D` | Game-level component base — same lifecycle, no entity ref, cached `game` |
| `CDBody` | `Node2D` | Behavior-set container inside an entity — sleeps/wakes on signals |
| `CDStage` | `Node2D` | Scene container — sleeps/wakes on signals; holds trapdoors/directors |

### Signal System — Hybrid Bus
Both entity and game buses use **native Godot signals** (via `add_user_signal()` / `bus_connect()`). All dynamic signals are **zero-arg**; data flows through `entity.blackboard` and `game.blackboard` dictionaries.

- **Emitter:** `entity.blackboard["key"] = value` → `entity.bus_emit("signal_name")`
- **Listener:** reads `entity.blackboard["key"]` in callback
- **Auto-populated keys each frame:** `"position"`, `"rotation"`, `"velocity"`
- `bus_emit()` auto-tracks the emitter in `_signal_emitters` for the current frame (enables `CDSelectSignalEmitter`)

### Bus Signals — Write-Before-Emit Contract (HARD RULE)

All dynamic bus signals are **zero-arg**. Event data flows through the blackboard, not the signal. This creates a temporal dependency between writer and listener:

> **The writer MUST write to the blackboard BEFORE emitting the signal.**
> **The listener MAY read from the blackboard inside the signal callback.**

```gdscript
# ✅ Correct — write data first, then signal
game.blackboard["captured_entity"] = target
game.bus_emit("player_captured")

# ❌ Wrong — listener reading the blackboard in the callback gets stale/missing data
game.bus_emit("player_captured")
game.blackboard["captured_entity"] = target
```

**Rationale:** Because the signal carries no payload, the listener's only source of truth is the blackboard at the moment the callback fires. Emitting before writing is a silent, intermittent bug — the connection still succeeds, the callback still runs, but the data isn't there yet.

**Scope:** This rule applies to every `bus_emit()` / `bus_emit_from()` call in the codebase — entity bus and game bus alike. It is the temporal equivalent of a data race and must be treated as a bug.

**When this contract is painful:** Genuinely local event data (e.g. "a body entered this area, *this* body") that has no cross-system shared-state meaning currently still has to round-trip through the blackboard. Typed bus payloads (non-zero-arg signals) for these cases are filed as Future Work; until then, use a dedicated blackboard key and obey write-before-emit.

### Deterministic Priority Cascade
```
REGISTRY(5) → INPUT(8) → BRAINS(10) → LEGS(20) → ENTITY(30) → COLLISION(35) → ARMS(40) → GUTS(50) → FACES(60) → VOICES(65) → STAGE(70) → MANAGER(75) → UPDATE(90)
```
Reserved for infrastructure (never set by components): REGISTRATION, INPUT, ENTITY, COLLISION, UPDATE.

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
| **Managers** | 75 | Stage lifecycle & cross-frame state — StageManager, StateManager, SignalManager, ScoreManager |

> **Manager vs Director boundary:** Both sit in `game components/`, but their roles differ. **Directors** (`RULES`/70) *orchestrate across groups each frame* — they gather entities, evaluate data-driven rules, and push intent onto blackboards/signals (aiming, formation, marching order, shooting, swoop) or perform one-shot swaps (stage). **Managers** (`MANAGER`/75) *own lifecycle and accumulated state* — staging entities in/out (StageManager), transitioning entities between groups as state (StateManager), running timed signal sequences (SignalManager), or evaluating scoring rules (ScoreManager). Rule of thumb: *if it pushes intent onto entities every frame, it's a director; if it reacts to triggers to change what's active or accumulated, it's a manager.*

### Directory Structure (V2 — actual)
```
Godot/scripts/
├── core/
│   ├── base classes/        — CDCueCard, CDEntityComponent, CDGameComponent, CDStageTrapdoor
│   ├── infrastructure/      — CDEntity, CDGame, CDCollisionBuffer, CDGroupRegistry, CDObjectPool, CDUpdater, CDStage, CDBody, etc.
│   └── resources/
│       ├── audio/           — CDNote, CDSoundDef, CDMusicTrack
│       ├── behavior/        — CDTransition, CDShape, CDScaler, CDSequenceStep, CDStageRule, etc.
│       ├── curves/          — CDCurve base + 12 curve types (AI path generation)
│       ├── formation/       — CDFormation, CDMarchingOrder
│       ├── infrastructure/  — CDCollisionGroup, CDEnums, CDUtilities
│       ├── selectors/       — CDSelector base + 6 selection strategies
│       ├── spawners/        — CDSpawnContext, CDGridLayout, CDGridRow, CDGridEquation
│       ├── triggers/        — CDTrigger base + 4 trigger types
│       └── visuals/         — CDFaceBinding
├── entity components/
│   ├── brains/              — player/ + ai action/ + ai movement/
│   ├── legs/                — directional setters/adders, positional setters/adders, other/
│   ├── arms/                — collision reactions/, death reactions/, triggered/, powerup/, other/
│   ├── guts/                — pools/, death/, physics/, detection/, input/, game logic/
│   ├── faces/               — 7 visual components
│   └── voices/              — 2 audio components
├── game components/
│   ├── cards/               — 5 cue cards (score, lives, timer, wave, capture)
│   ├── directors/           — 6 stage controllers (aiming, formation, marching_order, shooting, stage, swoop)
│   ├── managers/            — 4 stage managers (Stage, State, Signal, Score)
│   ├── goals/               — 3 win/lose conditions (group_count, score_threshold, signal)
│   ├── marks/               — 6 spatial triggers
│   ├── projectors/          — 2 visual post-processing
│   ├── speakers/            — 3 audio components
│   └── trapdoors/           — 3 spawners
└── effects/                 — 3 visual effects
```

**Full component catalogue (191 scripts):** `memory-bank/PROJECT_STATUS.md`

---

## 💬 CODE COMMENT CONVENTION

When asked to write or revise code comments in `.gd` files, follow this structure for each component class. Keep comments accurate to the existing code — describe, don't prescribe.

```gdscript
## [Component Name]
## [Category: Brains/Legs/Arms/Guts/Faces/Voices/Stage/Managers] · Priority: XX
##
## One- or two-sentence summary of what this component does and when it is active.
##
## Reads:           blackboard keys / resources this component reads
## Writes:          blackboard keys this component writes
## Emits:           signal_name (bus: entity/game)  — one per line
## Listens for:     signal_name (bus: entity/game)  — one per line
## Resources:       exported resource types (e.g. @export var curve: CDCurve)
extends ...

class_name ...

# --- Configuration (exports) ---
@export var example_property: float = 1.0  # units / meaning

# --- Internal state ---
var _internal_thing: int = 0

# --- Lifecycle ---
func _entity_ready() -> void:
    # Two-phase lifecycle: called after the entity is ready. Subscribe to buses here.
    ...

func _entity_exit() -> void:
    # Cleanup: disconnect bus subscriptions here.
    ...

# --- Processing ---
func _entity_process(delta: float) -> void:
    # Category priority is set on the node; this is the per-frame hook.
    ...
```

Conventions:
- **Header block** (the `##` lines) goes at the top of the file, immediately above `extends`. It is the contract: reads/writes/emits/listens/resources.
- **`# --- Section ---` dividers** separate Configuration / Internal state / Lifecycle / Processing. Use them to keep the file scannable.
- **Inline comments** (`#`) explain *why*, not *what*. "Submit as a request, don't set velocity" — good. "Set x to 5" — bad.
- **Never** comment out functional code. If code is dead, delete it.
- Keep comments tight — don't restate the GDScript in English.

---

## 💡 WHEN DISCUSSING CODE

- Reference actual file paths and line numbers when possible.
- Use `memory-bank/PROJECT_STATUS.md` as ground truth for what exists.
- When unsure how something works, say "I don't know" — don't hallucinate implementation details.
- If the user asks "should I do X?", explain the trade-offs and let them decide.

---

## 🤖 MODEL USAGE STRATEGY

| Model | Quota | When to use |
|:---|:---|:---|
| `zai/glm-4.7` | 1× | Default — general questions, explanations, pattern suggestions, documentation |
| `zai/glm-5.2` | 1× peak / 2× off-peak after Sept | Escalation — complex architecture, stuck on bugs, deep reasoning across systems |

Switch per-session with: `aider --model zai/glm-5.2`

---

## 🔄 AIDER WORKFLOW TIPS

- **Start sessions with `/ask`** — keeps Aider read-only by default.
- **Use `/clear`** between unrelated topics to reset context and save tokens.
- **Use `/add`** to load specific files for review (not for editing `.gd`/`.tscn`).
- **Use `/tokens`** to monitor context usage.
- **Batch questions** — combine related questions into one prompt to save tokens.
- **Use `/diff`** to review any proposed changes before accepting.