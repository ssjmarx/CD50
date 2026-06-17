# Current Task — CD50

> **What we're working on right now + where we're going.**
> Update this file when the active task or roadmap changes.

**Last Updated:** 2026-06-16

---

## 🔥 Active Task — Bug Blaster 2

The first game built on V2 architecture. We are proving the V2 component system by building a complete game from it.

### Current Focus: Capture Mechanics
Bug Blaster 2 needs the signature Galaga-style capture/rescue mechanic:
- Enemies dive (swoop) toward the player using `AISwoopBrain` + `CDCurve` paths
- `AITractorBeamBrain` interrupts the dive to perform a capture attempt
- `TractorBeamArm` is the active-frames arm that captures entities in the zone
- Captured entities must transition to a "captured" group and be escortable

**Components already built for this** (in codebase, ready to wire):
- `ai_tractor_beam_brain.gd` — `AITractorBeamBrain`
- `tractor_beam_arm.gd` — `TractorBeamArm`
- `ai_swoop_brain.gd` — `AISwoopBrain`
- `swoop_director.gd` — `SwoopDirector` + 13 `CDCurve` resources for paths
- `state_director.gd` / `state_manager.gd` — for group-as-state transitions (captured → escort)

### Next After Capture: Multi-Wave
Once capture works, Bug Blaster 2 needs multi-wave progression via the `WaveCard` → `Trapdoor` relay pattern.

---

## 🚀 Ship Status — itch.io Demo

**Status: Ready to ship.** All features complete. Only shipping tasks remain.

### Demo Game Roster — FINAL (12 games)
| Type | Count | Games |
|------|-------|-------|
| Remakes | 5 | Paddle Ball, Brick Breaker, Space Rocks, Bug Blaster, Block Drop |
| Remixes | 5 | Dogfight, Meteor Rally, Rock Breaker, Bug Drop, Space Bugs |
| Inversions | 2 | Planetary Attack!, Space Rocks Inverted |

### Completed Features
- ✅ 12 V1 games built and playable
- ✅ Polybius character (narrator/face/voice — judges, mocks, demands score)
- ✅ 5 Balatro-like modifiers (Shotgun, Overclocked, Feature Creep, Crunch Time, Scope Creep)
- ✅ Mini progression system (score-gated unlocks, top-5 high scores, initials entry)
- ✅ CRT shader (vector + raster modes, self-building controller)
- ✅ Web build exported, tested at 60fps on T480 target
- ✅ Butler deploy pipeline operational

### Remaining Shipping Tasks
- [ ] Flip itch.io page from private to public
- [ ] Add "Wishlist on Steam" button on itch page
- [ ] Add teaser line linking to Steam

> **Note:** The itch demo runs on V1. Bug Blaster 2 is the first V2 game. Once V2 proves out on Bug Blaster 2, subsequent games migrate to V2.

---

## 🎯 Vision — "Balatro but Arcade Games"

CD50 is **"Balatro but with classic arcade games instead of poker."**

A collection of classic arcade games from the 70s and 80s — remade and remixed — bound together by a Balatro-inspired system of modifiers. The player plays "runs" of 20-60 second arcade rounds, losing a life (and instantly progressing) if they die, ending the run when all three lives are lost. The goal: chase ever-higher scores by breaking the games with modifier combinations. Every game is built entirely from reusable, composable components. Zero game-specific scripts.

**Demo:** itch.io arcade cabinet with meta-orchestrator, fast rules, lives, cumulative scoring.
**Full release:** Steam, targeting October 2026 Next Fest, expanding toward 50 games.

### The Progression System (Full Release)
- **Modifiers ("Illegal Modifications")** — passive rules rewriters, unlock by lifetime score. Target: 50 at launch (5 for demo).
- **Playlists** — player-curated game sets (min 10 games), require collected "floppies".
- **Drops** — in-game pickups (modifiers, floppies, lore) at score thresholds.
- **Bosses** — longer multi-phase games every 9 levels during a run.
- **Glitches** — difficulty modifiers every 8 games to pressure deep runs.
- **Lore** — Polybius mystery meta-narrative pieced together from drops.

---

## 📅 Roadmap

| Phase | Timeline | Status |
|-------|----------|--------|
| Steamworks setup + itch.io pipeline | May 6–11 | ✅ Complete |
| Finalize arcade content (12 games) | May 12–31 | ✅ Complete |
| Polybius + modifiers + progression | May 18–31 | ✅ Complete |
| **V2 migration (Plans 19–28)** | **June** | **🔄 In progress — 172 scripts built, Bug Blaster 2 next** |
| Ship itch.io demo | June | 🔲 Ready to ship |
| Vertical slice (expand modifiers + games) | June–July | Planned |
| Steamworks integration (stats, leaderboards, achievements) | August 1–17 | Planned |
| Next Fest registration + store page | August 18–31 | Planned |
| Steam demo build + press preview | September | Planned |
| **Demo live + Next Fest** | **October 19–26** | **🎯 Target** |

---

## 📝 V2 Migration Status

The V2 architecture rebuild is substantially complete. All core infrastructure, all component categories, and the blackboard/signal system are implemented (172 scripts across Plans 19–28).

**What's done:**
- Core: CDEntity, CDGame, hybrid bus, collision buffer, group registry, object pool, updater, CDStage/CDBody containers
- All 8 component categories populated (Brains 17, Legs 15, Arms 16, Guts 19, Faces 7, Voices 2, Stage 27, plus 49 resources + 3 effects)
- Data-driven systems: triggers, selectors, curves, transitions, scalers, formations

**What remains:**
- Bug Blaster 2 (first V2 game) — capture mechanics, then multi-wave
- Migrate remaining V1 games to V2 (post-demo)