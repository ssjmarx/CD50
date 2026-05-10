# Current Goal

**Last Updated:** 2026-05-09  
**Status:** Active — Plan 15 Phase 2 (Polybius Character) + shipping itch.io demo

---

## Active Priority: Ship the Demo (May 2026)

The project has pivoted from building new games to shipping what we have. The immediate goal is to get an itch.io demo and a Steam "Coming Soon" page live by end of May 2026.

**Full deadline schedule:** `memory-bank/06 - Deadlines.md`

### This Week (May 6–11)
- Steamworks: pay fee, create App ID, tax/bank info, Coming Soon page
- itch.io: create game page, decide web vs native, test Butler pipeline

### Mid–Late May (May 12–31)
- Finalize arcade mode content and export
- Upload to itch via Butler
- Add Steam wishlist CTA to itch page
- Plans 14–15 (arcade juice) to polish the experience

---

## Near-Term Plans

### Plan 14 — Arcade Juice Part 1: Custom CRT Shader
**Status:** COMPLETE  
**Timeline:** Completed May 6, 2026  
**Scope:** Replaced heavy CRT addon with lightweight custom shader + persistence shader + vector monitor mode with SubViewport-based phosphor persistence. No per-body phosphor component needed — shader-based approach handles trails automatically.

### Plan 15 — Arcade Orchestrator Juice
**Status:** IN PROGRESS  
**Timeline:** Before itch export (late May)  
**Scope:** Three phases — Copyright rename pass (bootleg cabinet names) + Copyright-safety visual changes (formation/color/shape/layout tweaks for all 5 remakes) + Polybius face/voice integration. Full plan in `planning/15 - Arcade Orchestrator Juice.md`.

**Phases 1 & 1.5 COMPLETE:**
- Phase 1: All games renamed (copyright-safe bootleg names), first itch.io export
- Phase 1.5: Bug Blaster 3×18 formation, Block Drop color/juice rework (warm colors, cascading explosions, rotating previews), Brick Breaker flag coloring + wider layout, Space Rocks ship+UFO redesign, Paddle Ball checkerboard center line
- New components: `checkerboard_line`, `flag_palette`, `flag_resource`, `death_brick_explode`

**Phase 2 NEXT — Polybius Character:**
- Step 2a: Create `polybius_face.gd` — vector CRT face drawing + expression states

### Plan 16 — Cambrian Remix Explosion
**Status:** Not started  
**Timeline:** Mid–late May (after Plans 14–15)  
**Scope:** 5 remakes + 10 remixes/originals (3 new games designed, 4 slots TBD), 5 Balatro-like modifiers with score gate unlocks, semi-random playlist mode, local high score persistence. Full plan in `planning/16 - Cambrian Remix Explosion.md`.

### Plan 17 — Arcade Juice Post-Launch
**Status:** Not started  
**Timeline:** After itch launch  
**Scope:** VRAM Boot Screen, Attract Mode System, Coin Drop Boot Sequence. Extracted from Plan 14 — deferred past first itch release. Full plan in `planning/17 - Arcade Juice Post-Launch.md`.

---

## Mid-Term (June–October 2026)

### June–July — Vertical Slice Content
- Expand modifier system beyond the initial 5 (more contraband, tokens, features)
- Score progression / ranking system (10k → 1m → 1b)
- Polish core loop to 20–30 second snappy runs
- Fill remaining 4 remix slots from Plan 16

### August 1–17 — Steamworks Integration
- GodotSteam integration
- Stats, leaderboards, achievements
- In-game UI for all of the above

### August 18–31 — Next Fest Registration
- Register for October Next Fest
- Finalize store page, capsule images, trailer

### September — Steam Demo Build + Press
- Steam demo build (with Steam backend features)
- Submit for review by Sep 21
- Press preview window Sep 21–30

### October — Launch + Next Fest
- Demo goes live on Steam before Oct 19
- Next Fest Oct 19–26
- Leave demo up after fest

---

## Deferred

The following plans have been **deleted** from the active pipeline. The component ideas may resurface post-launch if they serve a remix or modifier.

- ~~Plan 14 — Snake + Light Cycles~~ (trail_spawner, cycle_ai, food_spawner)
- ~~Plan 15 — Qix + Xonix~~ (territory_grid, line_drawer, area_filler)

---

## Complete

| Plan | Description | Completed |
|------|-------------|-----------|
| 14 | Arcade Juice Part 1 (Custom CRT Shader, Vector Monitor, Phosphor Trails) | 2026-05-06 |
| 13 | Arcade Orchestrator (Interface Takeover, Scrolling Transitions, Fast Rules) | 2026-05-05 |
