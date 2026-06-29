# Current Task — CD50

> **What we're working on right now + where we're going.**
> Update this file when the active task or roadmap changes.

**Last Updated:** 2026-06-28

---

## 🔥 Active Task — Port the V1 Roster to V2, Integrate the Remixes, Then Delete V1

Bug Blaster 2 — the first complete V2 game — is **done**. It proves out the architecture end-to-end (see §"Bug Blaster 2 — Shipped" below). The focus now shifts to **porting the remaining V1 games to V2**, **integrating the remixes into the V2 `CDStage` paradigm**, and then **deleting `Godot/v1/`** once parity is reached.

### Why this task
The itch.io demo shipped on V1 with 12 games. V2 is the future: zero game-specific scripts, full composability. Every V1 game needs a V2 remake so the demo (and the eventual Steam release) run on a single architecture. V1 is kept as reference during the port and deleted when no longer needed.

### The remix-integration pattern
The V1 remixes won't each live in a separate scene the way the remakes do. Each remix will live **on the base game** and be **woken by a signal rather than loaded into its own scene** — the same `CDStage` sleep/wake pattern Bug Blaster 2's `Level1Stage`…`Level5Stage` already demonstrates. One game root, multiple `CDStage` nodes (one per remix variant), only the active one running at a time. This keeps the remix layer as pure scene composition, with no per-remix scripts.

### V2 Port Backlog (V1 demo roster)
The 12 demo games, by port status. Components listed are the **new V2 components** each port is expected to exercise/prove.

| # | Game | Type | V2 Status | Key V2 components it exercises |
|---|------|------|-----------|--------------------------------|
| 1 | **Bug Blaster 2** *(Galaga)* | Remake | ✅ **Shipped** | `CDBody`, `StateManager`/`CDTransition`, `SwoopDirector`+`CDCurve`, `TractorBeamArm`+`CDMark`, `FormationDirector`, `CDStage`×5, `ScoreManager`/`ScoreCard`, `WaveCard` |
| 2 | Paddle Ball *(Pong)* | Remake | 🔲 Planned | `PlayerMoveBrain`, `DirectMovementLeg`, `ScreenWrapLeg`, `CollisionBuffer`, `ScoreCard` |
| 3 | Brick Breaker *(Breakout)* | Remake | 🔲 Planned | `PlayerMoveBrain`, `GridLayout`, collision reactions, `GroupCountGoal` |
| 4 | Space Rocks *(Asteroids)* | Remake | 🔲 Planned | `EngineLeg`, `DirectRotationLeg`, `GunArm`, `ScreenWrapLeg`, `DieOutOfBoundsGuts` |
| 5 | Block Drop *(Tetris)* | Remake | 🔲 Planned | `GridMovementLeg`/`GridDropLeg`, `PieceSplitterArm`, `TSpinDetectorGuts`, `OccupancyMark` |
| 6 | Dogfight | Remix | 🔲 Planned | `AIChaseBrain`, `AIEscortBrain`, `DamageOnHitArm`, two-player input |
| 7 | Meteor Rally | Remix | 🔲 Planned | `AIPathMoveBrain`+`CDCurve`, `AIFleeBrain`, timer racing |
| 8 | Rock Breaker | Remix | 🔲 Planned | `GridTrapdoor`, `CDGridLayout`, split-asteroid chain |
| 9 | Bug Drop | Remix | 🔲 Planned | `GridDropLeg`, `ShapeColliderGuts`, line-clear variant |
| 10 | Space Bugs | Remix | 🔲 Planned | `FormationDirector`+`CDMarchingOrder`, `GridTrapdoor`, `ShootingDirector` |
| 11 | Planetary Attack! | Inversion | 🔲 Planned | `StageDirector` swaps, difficulty-inversion via `CDWaveScaler` |
| 12 | Space Rocks Inverted | Inversion | 🔲 Planned | Inverted Asteroids — `AIChaseBrain` asteroids, `CDWaveScaler` |

### Porting approach (proposal, not enforced)
1. **Start with the simplest games** (Paddle Ball, Brick Breaker) — they exercise the core pipeline with minimal components and confirm the reusable layer works for non-Galaga genres.
2. **Then Asteroids-family** (Space Rocks, Rock Breaker, Space Rocks Inverted) — share `EngineLeg`/rotation physics, so build them as a batch.
3. **Then the grid games** (Block Drop, Bug Drop) — share `Grid*Leg` + `GridTrapdoor`, so build as a batch.
4. **Then the AI-heavy remixes** (Dogfight, Meteor Rally, Space Bugs, Planetary Attack!).
5. **Once all 12 are in V2 and playable, delete `Godot/v1/`.**

> **Each port is an opportunity to find missing components.** If a game needs behavior that no current component provides, first check whether a data resource (trigger/selector/curve/scaler/formation) can express it. If not, design a new generic component — never a game-specific script. Update `memory-bank/PROJECT_STATUS.md` when components are added.

### What "done" looks like for this task
- [ ] All 11 remaining demo games ported to V2 and playable
- [ ] `Godot/v1/` deleted
- [ ] V2 catalogue stable (no further port-driven additions pending)
- [ ] Itch.io demo re-exported from V2
- [ ] `memory-bank/PROJECT_STATUS.md` reflects final V2 state

---

## ✅ Bug Blaster 2 — Shipped

The first complete V2 game. Galaga-style: enemies spawn from the edges, swoop to a formation, dive at the player, some attempt capture, five looping levels with wave-scaling difficulty. **Implemented entirely in `.tscn` — zero game-specific scripts.**

Scenes: `Godot/games/bug_blaster_2.tscn`, `Godot/entities/player/bug_blaster_2_player.tscn`.

### What it proves
- **The "fat player" / `CDBody` pattern** — three behavior sets (Active / Captured / Rescued) sleep/wake on signals, producing the full capture→escort→rescue→wingman loop with no code.
- **Group-as-state via `StateManager`** — entities move `"formation"` → `"diving"` (and the player `"players"` → `"enemies"`) through `CDTransition` resources, not scripts.
- **`CDStage` sleep/wake for levels** — five stages hold all level content; `StageManager` + `CDStageRule` (gated by `CDCompositeTrigger`: completion signal AND `CDGroupCountTrigger` enemies==0) advances and loops.
- **Data-driven orchestration** — `SwoopDirector`+`CDCurve`, `FormationDirector`+`CDFormation`/`CDMarchingOrder`, `ShootingDirector`+selectors, all configured as resources.
- **Scoring as a decoupled chain** — `ScoreOnCollisionArm`/`ScoreOnDeathArm` → `ScoreManager` (`CDScoringRule`) → `ScoreCard` → `ScoreThresholdGoal`.
- **Spatial→signal bridge** — `TractorMark` fires `"fire_tractor_beam"` on a spider's entity bus when it enters at capture height.

See `USAGE.md` §9 for the full end-to-end walkthrough.

---

## 🚀 Ship Status — itch.io Demo

**Status: V1 demo ready to ship. V2 demo pending the port above.**

### Demo Game Roster — FINAL (12 games)
| Type | Count | Games |
|------|-------|-------|
| Remakes | 5 | Paddle Ball, Brick Breaker, Space Rocks, Bug Blaster, Block Drop |
| Remixes | 5 | Dogfight, Meteor Rally, Rock Breaker, Bug Drop, Space Bugs |
| Inversions | 2 | Planetary Attack!, Space Rocks Inverted |

### Completed (V1 demo)
- ✅ 12 V1 games built and playable
- ✅ CRT shader (vector + raster modes, self-building controller)
- ✅ Web build exported, tested at 60fps on T480 target
- ✅ Butler deploy pipeline operational

### Remaining Shipping Tasks
- [ ] Flip itch.io page from private to public
- [ ] Add "Wishlist on Steam" button on itch page
- [ ] Add teaser line linking to Steam
- [ ] Re-export demo from V2 once the port is complete

> **Note:** The itch demo currently runs on V1. Bug Blaster 2 is the first V2 game and is complete. The V2 port backlog (above) brings the rest over.

---

## 📅 Roadmap

| Phase | Timeline | Status |
|-------|----------|--------|
| V2 architecture build (Plans 19–29) | June | ✅ Complete — 191 scripts |
| Bug Blaster 2 (first V2 game) | June | ✅ Complete — shipped |
| **Port V1 roster to V2 + integrate remixes + delete V1** | **June–July** | **🔄 In progress** |
| Ship itch.io demo (V2) | July | 🔲 Pending port |
| Steamworks integration (stats, leaderboards, achievements) | August | Planned |
| Next Fest registration + store page | August | Planned |
| **Demo live + Next Fest** | **October** | **🎯 Target** |

---

## 📝 V2 Migration Status

The V2 architecture rebuild is **complete** — 191 scripts across Plans 19–29. All core infrastructure, all component categories, the blackboard/signal system, and the data-driven resource layer are implemented and proven by Bug Blaster 2.

**Done:**
- Core: `CDEntity`, `CDGame`, `CDBody`, `CDStage`, hybrid bus, collision buffer/matrix, group registry, object pool, updater, sound bank
- All 8 component categories populated (Brains 17, Legs 15, Arms 16, Guts 19, Faces 7, Voices 2, Stage components: cards 5 / directors 6 / managers 4 / goals 3 / marks 6 / projectors 3 / speakers 3 / trapdoors 3, plus 53 resources + 6 effects)
- Data-driven systems: triggers, selectors, curves, transitions, scalers, formations, marching orders
- **Bug Blaster 2** — first complete V2 game, shipped

**Remaining:**
- Port the 11 remaining V1 demo games to V2
- Delete `Godot/v1/` once parity is reached
- Re-export the itch.io demo from V2

---

## ✅ Closed Maintenance — Comment-Convention Sweep (2026-06-28)

A prior session reported `Godot/scripts/` comment-clean via `grep -rnE '^\s*#[^#]'`. That gate was **insufficient** — it only checks line-leading single-`#` and misses inline trailing `#` and header-order violations. A re-audit found and fixed **8 files**:

- **6 inline-`#` files (22 comments → `##`):** `cd_enums.gd` (14), `swoop_director.gd` (3), `menacing_vector_face.gd` (2), `cd_game_control.gd` (1), `signal_manager.gd` (1), `scrolling_stars_effect.gd` (1).
- **2 header-order files** (3-line header displaced below `@tool`): `grid_trapdoor.gd`, `marching_order_breathe.gd` — header moved above `@tool`.

No functional code touched (CONVENTIONS §1). The full tree now passes all three gates below.

**Stronger re-audit gate (use this, not the old one):**
```bash
## 1. line-leading single-#  2. inline trailing single-#  3. lone-# lines
grep -rnE '^\s*#[^#]'     Godot/scripts/ --include='*.gd'   # exit 1 = clean
grep -rnE '\S\s+#[^#]'    Godot/scripts/ --include='*.gd'   # exit 1 = clean
grep -rnE '^\s*#\s*$'     Godot/scripts/ --include='*.gd'   # exit 1 = clean
## header check: every .gd must open with "## " (no @tool before it)
find Godot/scripts/ -name '*.gd' -print0 | while IFS= read -r -d '' f; do \
  first=$(grep -m1 -vE '^\s*$' "$f"); case "$first" in '## '*) ;; *) echo "BAD: $f -> $first";; esac; done
```

> Rules 3/4/5 (editor-description lines, in-function comment thresholds, separator usage) remain judgment-call and are not grep-verifiable.
