# CD50

**"Balatro but with classic arcade games instead of poker."**

CD50 is a modular arcade game collection built in [Godot 4.5](https://godotengine.org). It features classic arcade games from the 70s and 80s—remade, remixed, and inverted—bound together by a roguelite modifier system. 

The true core of CD50 is its **V2 Composable Architecture**. Every game is assembled entirely from generic, reusable components. **Zero game-specific scripts exist anywhere in the project.**

Currently, the project is migrating to the V2 architecture. **Bug Blaster 2** is the first game built entirely on the V2 component system, acting as the proving ground for the architecture's capabilities.

---

## The V2 Architecture

To make a game without game-specific scripts, CD50 uses a strict, data-driven component system. Entities are blank physics shells (`CDEntity`), and all behavior is injected by attaching components.

### The Three Rules

1. **Composition over inheritance:** `CDEntity` is a blank slate. All behavior comes from attached components.
2. **Signals, not calls:** Components never call methods on other components. They emit signals and let the recipient decide what to do. This eliminates hard coupling.
3. **Single-purpose components:** Each component does exactly one thing. A Brain generates intent. A Leg moves. An Arm affects the outside world. A Guts tracks internal state.

### The Priority Pipeline

Every frame, components execute in a deterministic priority cascade. Lower priority runs earlier. This eliminates frame-ordering bugs—every component knows exactly when it runs relative to every other component, regardless of its position in the scene tree.

```text
REGISTRATION → INPUT → INTENT → STEERING → PHYSICS → COLLISION → INTERACTION → STATE → VISUAL → AUDIO → RULES → MANAGER → UPDATE
```

### Component Categories

| Category | Priority | Role | Examples |
|----------|----------|------|---------|
| **Brains** | 10 | Generate intent from input or AI | `PlayerMoveBrain`, `AIChaseBrain`, `AISwoopBrain` |
| **Legs** | 20 | Execute movement from intent | `DirectMovementLeg`, `EngineLeg`, `GridMovementLeg` |
| **Arms** | 40 | Affect other entities/game state | `DamageOnHitArm`, `GunArm`, `TractorBeamArm` |
| **Guts** | 50 | Track internal entity state | `HealthpoolGuts`, `TimerGuts`, `LockDetectorGuts` |
| **Faces** | 60 | Draw entity appearance | `VectorFace`, `SpriteFace`, `DeathEffectFace` |
| **Voices** | 65 | Play entity-level audio | `SoundVoice`, `ContinuousVoice` |
| **Stage** | 70 | Manage game-level logic | `ScoreCard`, `GridTrapdoor`, `FormationDirector` |

---

## How It Works: Building Bug Blaster 2

Because of the strict priority pipeline and signal-driven design, creating complex arcade mechanics is as simple as snapping components together. Bug Blaster 2 uses this to implement its signature Galaga-style capture/rescue loop:

**The Player Ship:**
*   Attach a `PlayerMoveBrain` (Priority 10) to read keyboard inputs and shout `"move"`.
*   Attach a `DirectMovementLeg` (Priority 20) to hear `"move"` and apply velocity.
*   Attach a `GunArm` (Priority 40) to fire projectiles when the player hits the action button.

**The Capturing Spider:**
*   Attach an `AISwoopBrain` (Priority 10) to dive along a `CDCurve` path toward the player.
*   Attach a `TractorBeamArm` (Priority 40) that activates an overlapping physics zone to capture the player.
*   When the player is hit, the `TractorBeamArm` emits a `"player_captured"` signal across the buses. 

The game logic emerges entirely from how these 172 reusable components are wired together in the Godot editor.

> **Want to build your own games or components?**
> Check out **[USAGE.md](USAGE.md)** for the complete, deep-dive guide into the hybrid signal bus, component lifecycle, object pooling, and anti-patterns.

---

## The Signal System

Components communicate through two decoupled signal buses:

1. **Entity Bus (High Frequency):** Native Godot signals on individual entities. Brains emit `"move"`, Legs consume it. Arms hear `"collision"` and react.
2. **Game Bus (Low Frequency):** Native Godot signals on the game root. Used for macro events like `"score_gained"`, `"wave_cleared"`, or `"player_captured"`.

All dynamic signals are **zero-arg**. Data is passed securely through `entity.blackboard` or `game.blackboard` dictionaries.

---

## Project Structure

```text
Godot/
├── scripts/
│   ├── core/                    — CDEntity, CDGame, base classes, infrastructure
│   ├── entity components/
│   │   ├── brains/              — Intent generators
│   │   ├── legs/                — Movement executors
│   │   ├── arms/                — World-interaction components
│   │   ├── guts/                — Internal state trackers
│   │   ├── faces/               — Visual representations
│   │   └── voices/              — Entity audio components
│   ├── game components/
│   │   ├── cards/               — UI display components
│   │   ├── directors/           — Stage controllers
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

*   **Engine:** [Godot Engine 4.5](https://godotengine.org) (GDScript)
*   **Audio:** 100% procedural synthesis at runtime. All sound effects are generated in real-time via `AudioStreamGenerator`.
*   **Visuals:** Custom CRT shader suite (barrel warp, chromatic aberration, bloom, vignette, hum bar) + vector monitor mode with phosphor persistence.
*   **Fonts:** [Kenney](https://kenney.nl) retro pixel fonts, used under the terms in `LICENSE.ASSETS`.

### Music
*   **El Manisero** — Moisés Simons (1928) · Public Domain
*   **Son de la Loma** — Miguel Matamoros (1922) · Public Domain
*   Rendered with [RoyTheRailfanner's 8-Bit NES Soundfont](https://musical-artifacts.com/artifacts/2759), licensed under CC-BY 3.0.
*   **Hunted by Machines** — [Karl Casey](https://www.youtube.com/@WhiteBatAudio) @ [White Bat Audio](https://whitebataudio.com/), licensed under CC-BY 4.0.
