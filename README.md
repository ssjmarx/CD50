# CD50

**A Godot 4.5 engine for building arcade games from generic, reusable components — zero game-specific scripts.**

CD50's core is its **V2 Composable Architecture**: every game is a `.tscn` assembly of small, single-purpose components, wired together with signals and data resources rather than code. There are **191 reusable components** and no game-specific scripts anywhere in the project. The interesting part isn't the games — it's the runtime that makes composition, signal buses, and a deterministic priority cascade replace traditional per-game logic.

The architecture is proven out by **Bug Blaster 2** (a Galaga-style game with capture/rescue and five looping levels), implemented entirely as scene composition.

> **New to the project?** Read **[USAGE.md](USAGE.md)** — the deep-dive guide to how every component category works together, with a full end-to-end walkthrough of Bug Blaster 2.

---

## Quick Start

1. Open the `Godot/` folder in **Godot 4.5**.
2. Run **`Godot/games/bug_blaster_2.tscn`** — that's the whole game; it boots into attract mode, press start to play.
3. Open **`Godot/entities/player/bug_blaster_2_player.tscn`** to see how a player is composed: a `PlayerMoveBrain` (intent), a `DirectMovementLeg` (movement), a `GunArm` (fire), and **three `CDBody` behavior sets** (`ActiveBody` / `CapturedBody` / `RescuedBody`) that sleep and wake on signals to produce the capture→rescue→wingman loop — with no code.
4. Back in the game scene, expand **`Stages/`** to see five `Level#Stage` (`CDStage`) nodes holding all the per-level content. They sleep/wake on signals driven by `StageManager` rules and `SignalManager` sequences — only one level runs at a time even though all five are present.

> Want the full picture (how the buses, blackboard, priority cascade, and object pool make this work)? Jump to **[USAGE.md](USAGE.md)**.

---

## The Big Idea

- **Composition over inheritance** — `CDEntity` is a blank physics shell; behavior comes entirely from attached components.
- **Signals, not calls** — components never call methods on each other. They emit on an entity bus or a game bus; data flows through blackboards.
- **A deterministic priority cascade** — every frame runs `REGISTRY → INPUT → BRAINS → LEGS → ENTITY → COLLISION → ARMS → GUTS → FACES → VOICES → STAGE → MANAGER → UPDATE`, so intent is generated before it's consumed and collisions resolve before reactions fire.

The payoff: most "design changes" are inspector edits to data resources (triggers, selectors, curves, formations, scoring rules), not code.

---

## Documentation Map

| Document | What it's for |
|:---|:---|
| **[USAGE.md](USAGE.md)** | *Why & how* — the deep architecture guide (buses, priority cascade, component collaboration, worked example) |
| **CONVENTIONS.md** | *Rules* — AI editing guardrails, the write-before-emit contract, code-comment convention |
| **memory-bank/PROJECT_STATUS.md** | *Catalogue* — what exists right now (every component, grouped) |
| **memory-bank/CURRENT_TASK.md** | *Now* — active work + roadmap |
| **COMBINED_READMES.md** | *Reference* — per-component authoring detail |

---

## Project Structure

```text
Godot/
├── scripts/
│   ├── core/                    — CDEntity, CDGame, base classes, infrastructure, resources
│   ├── entity components/
│   │   ├── brains/              — Intent generators
│   │   ├── legs/                — Movement executors
│   │   ├── arms/                — World-interaction components
│   │   ├── guts/                — Internal state trackers
│   │   ├── faces/               — Visual representations
│   │   └── voices/              — Entity audio components
│   ├── game components/
│   │   ├── cards/               — UI display components
│   │   ├── directors/           — Frame-active group orchestrators
│   │   ├── managers/            — Lifecycle + accumulated state
│   │   ├── goals/               — Win/lose conditions
│   │   ├── marks/               — Spatial triggers
│   │   ├── projectors/          — Visual post-processing
│   │   ├── speakers/            — Audio components
│   │   └── trapdoors/           — Stage spawners
│   └── effects/                 — Visual effects
├── scenes/                      — Scene assemblies (entity + game component instances)
├── entities/                    — Entity prefabs
├── games/                       — Game scene roots
└── shaders/                     — CRT + persistence shaders
```

---

## Tech Stack & Attribution

* **Engine:** [Godot Engine 4.5](https://godotengine.org) (GDScript)
* **Audio:** 90% procedural synthesis at runtime, with .ogg files for background music. Sound effects are generated in real-time via `AudioStreamGenerator`.
* **Visuals:** Custom CRT shader suite (barrel warp, chromatic aberration, bloom, vignette, hum bar) + vector monitor mode with phosphor persistence.
* **Fonts:** [Kenney](https://kenney.nl) retro pixel fonts, used under the terms in `LICENSE.ASSETS`.
* **AI Toolchain:** 
    - **Nemotron 3** – used for architectural planning and design.
    - **GLM 4.7 Flash** – used for code edits and incremental changes.
    - **DeepSeek V4 Flash** – used for major implementation tasks and refactorings.

### Music
* **El Manisero** — Moisés Simons (1928) · Public Domain
* **Son de la Loma** — Miguel Matamoros (1922) · Public Domain
* Rendered with [RoyTheRailfanner's 8-Bit NES Soundfont](https://musical-artifacts.com/artifacts/8369), licensed under CC-BY 3.0.
* **Hunted by Machines** — [Karl Casey](https://www.youtube.com/@WhiteBatAudio) @ [White Bat Audio](https://whitebataudio.com/), licensed under CC-BY 4.0.
