# Current Goal

**Last Updated:** 2026-05-03  
**Status:** Active — Plan 14 (Snake + Light Cycles)

---

## Active Plan: 14 — Snake and Light Cycles

Two games sharing `trail_spawner` as the core component. Full plan in `planning/14 - Snake and Light Cycles.md`.

| Phase | Description | Status |
|-------|-------------|--------|
| 14 | Light Cycles + Snake | Not started |

### Key New Components
- **`trail_spawner`** — Spawns static collision walls behind moving bodies (shared core: LC = permanent, Snake = growing body)
- **`cycle_ai`** — Raycast wall avoidance brain
- **`food_spawner`** — Spawns collectible at random open position (Snake)

---

## Next: Plan 15 — Qix and Xonix

Territory claiming games sharing `territory_grid` + `line_drawer` + `area_filler`. Full plan in `planning/15 - Qix and Xonix.md`.

| Phase | Description | Status |
|-------|-------------|--------|
| 15 | Qix + Xonix | Pending (after Plan 14) |

### Key New Components
- **`territory_grid`** — 640×360 pixel bitmap with flood fill
- **`line_drawer`** — Drawing state machine, pixel path recording, reconnection detection
- **`area_filler`** — Flood fill with Qix avoidance
- **`qix_ai`** — Random walk in unclaimed territory
- **`sparx_ai`** — Border tracing brain
- **`mine_ai`** — Border expansion brain (Xonix only)

---

## Future: Plan 16 — Cambrian Explosion (Remixes)

Mass remix phase combining components from Plans 14–15 with the existing library to reach 20 games.

### Path to 20

8 existing + 4 remakes (Snake, LC, Qix, Xonix) + remixes from Plan 16 = **20 games**

---

## On Hold: Plan 13 — Arcade Orchestrator

Phases 0–1 complete, Phase 2 mostly complete, Phase 3 complete. Remaining:
- Scrolling transitions between games
- Preloading (`ResourceLoader.load_threaded_request`)

---

## Future Phases (Post-Plan 14)

- Phase 4 — Polybius face + voice + dialogue
- Phase 5 — Scoreboard with local high scores
- Phase 5.5 — Kill screen secret + code entry
- Phase 6 — Juice: CRT, sounds, animations
- Phase 7 — Ship: itch.io export