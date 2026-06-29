# CD50 — Aider Conventions & Rules

> **This file is the single source of truth for AI behavior in this repo.**
> Aider auto-reads `CONVENTIONS.md` when present. If it does not, run:
> `aider --read CONVENTIONS.md`

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

## 🧠 THE AI ASSISTANT'S ROLE

### 1. Bouncing Ideas
- Discuss architecture decisions, design patterns, and trade-offs.
- Help evaluate different approaches to a problem.
- Ask clarifying questions to sharpen the user's thinking.
- Offer alternatives the user may not have considered.

### 2. Organizing Planning Documents & Brainstorming
- Create, update, and reorganize files in `memory-bank/` and `planning/`.
- Structure brainstorming sessions into actionable plans.
- Maintain accurate documentation of the project state.
- Draft planning documents, proposals, and implementation outlines.

### 3. Writing Code Comments
- Help write clear, descriptive comments for existing code.
- Suggest comment conventions (purpose, signals listened/emitted, etc.).
- Document signal flows and component relationships.
- Do NOT write functional code hidden inside comments — comments describe existing code only.

### 4. Organizing the Project
- Suggest file organization and naming conventions.
- Help reorganize functions within scripts to follow Godot best practices.
- Identify code that could be refactored into components.
- Point out when project structure deviates from the component architecture.

### 5. Tutoring & Coaching
- Explain Godot concepts: nodes, signals, scenes, groups, physics layers.
- Explain GDScript patterns and idioms.
- Teach programming principles: composition over inheritance, signal-driven architecture, separation of concerns.
- Guide the user toward solutions rather than providing them directly.
- Answer "why does this pattern work?" and "what's the Godot way to do X?" questions.

---

## 📋 MANDATORY CONTEXT CHECK

Before answering substantive questions, verify:
1. `memory-bank/PROJECT_STATUS.md` — codebase truth: architecture, component catalogue, patterns.
2. `memory-bank/CURRENT_TASK.md` — active work: what we're building now + roadmap.
3. If either file appears outdated or inaccurate, **flag this to the user first** before proceeding.

For deep architectural reference: `USAGE.md` and `planning/V2 Rules.md`.

---

## 📝 MEMORY BANK MAINTENANCE

The memory bank is **two files only**. Both are auto-loaded by Aider (see `.aider.conf.yml`). Keep them lean and accurate.

### `memory-bank/PROJECT_STATUS.md` — "What exists"
This is the **factual codebase reference**. Update it when the codebase changes.

**Update when:**
- A script is **added, removed, or renamed** → update the component catalogue + count summary.
- A new **pattern or anti-pattern** emerges → add to the reference tables.
- The **architecture** changes (new base class, priority shift, signal system change) → update the overview.

**Do NOT update for:**
- Work-in-progress that isn't committed yet.
- Opinion or discussion — this file is facts only.

### `memory-bank/CURRENT_TASK.md` — "What we're doing"
This is the **active work pointer**. Update it frequently as focus shifts.

**Update when:**
- The **active task** changes (e.g., finishing capture mechanics, moving to multi-wave).
- A **milestone completes** (check the roadmap, mark it ✅).
- The **ship status** changes (demo shipped, new blocker found, etc.).
- The **roadmap** is revised (dates move, phases reorder).

**Do NOT update for:**
- Every minor sub-task — keep it at the milestone level.
- Completed work that belongs in `PROJECT_STATUS.md` instead (e.g., "we added a new component" updates the catalogue, not the task).

### Rule of thumb
If it's about **what the code IS** → `PROJECT_STATUS.md`.
If it's about **what we're DOING** → `CURRENT_TASK.md`.
If unsure, ask the user which file to update.

---

## 🏗️ PROJECT CONTEXT — V2 COMPOSABLE ARCHITECTURE

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
| `CDGameComponent` | `Node2D` | Stage component base — same lifecycle, no entity ref |

### Signal System — Hybrid Bus (native signals + blackboard)
Both entity and game buses use **native Godot signals** (via `add_user_signal()` / `bus_connect()`). All dynamic signals are **zero-arg**; data flows through `entity.blackboard` and `game.blackboard` dictionaries.

- **Emitter:** `entity.blackboard["key"] = value` → `entity.bus_emit("signal_name")`
- **Listener:** reads `entity.blackboard["key"]` in callback
- **Auto-populated keys each frame:** `"position"`, `"rotation"`, `"velocity"`
- `bus_emit()` auto-tracks the emitter in `_signal_emitters` for the current frame (enables signal-aware selectors)

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

> **Manager vs Director boundary (post-cleanup):** Both sit in `game components/`, but their roles differ. **Directors** (`RULES`/70) *orchestrate across groups each frame* — they gather entities, evaluate data-driven rules, and push intent onto blackboards/signals (aiming, formation, marching order, shooting, swoop) or perform one-shot swaps (stage). **Managers** (`MANAGER`/75) *own lifecycle and accumulated state* — staging entities in/out (StageManager), transitioning entities between groups as state (StateManager), running timed signal sequences (SignalManager), or evaluating scoring rules (ScoreManager). Formerly this boundary was muddied by duplicate director/manager pairs (state, signal); those were collapsed — the manager is canonical in each case.

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

**Full component catalogue (172 scripts):** `memory-bank/PROJECT_STATUS.md`

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