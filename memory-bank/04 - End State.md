# End State: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-05

---

## Vision

CD50 is a componentized arcade game collection demonstrating that classic arcade games can be built entirely from reusable, composable components — zero game-specific scripts. Every game is a scene assembly. The project ships as an itch.io arcade cabinet with a meta-level orchestrator that runs games in sequence with fast rules, lives, and cumulative scoring.

---

## Final State

- **8 playable games** — Paddle Ball, Brick Breaker, Space Rocks, Meteor Rally, Dogfight, Bug Blaster, Block Drop (Modern), Rock Breaker
- **89 components** across 10 categories (Core, Bodies, Brains, Legs, Arms, Components, Rules, Flow, Effects, Hub)
- **Zero game scripts** — every game is a `UniversalGameScript` root with attached components
- **Full Block Drop suite** — Physics-based grid (Plan 10), Modern Block Drop Guideline features (Plan 11): ghost piece, hold piece, T-spin detection, combo/B2B/level scoring, lock delay move limit. Juice and polish (Plan 12): 10 procedural sounds, score tick-up, line flash, smooth collapse, brick-style cells.
- **Arcade orchestrator** — Boot → shuffle playlist → play games with fast rules → track lives/score/multiplier → game over → replay. 8 tuned game entries for 15–45s arcade pacing. Scrolling transitions between all screens. Interface Takeover: each game's child Interface hijacked by AO, no separate AO Interface node.
- **All features toggleable** — Modern Block Drop features are additive components with sensible defaults; existing games unchanged

---

## Architecture Achievements

- Clean signal flow: Brains → Body → Legs/Arms → Components/Rules/Flow → Effects
- UGS as event bus: components communicate through game-level signals (`hold_requested`, `t_spin_detected`, `piece_settled`)
- Physics-based grid: Block Drop uses no grid data structure — all detection via physics queries
- Pre-lock timing pattern: `piece_pre_lock` fires before `piece_locked` for pre-lock inspection
- Component toggleability: features enabled/disabled by including/excluding component scenes
- UGS Mode enum: STANDALONE vs ARCADE — same game scenes work standalone or under orchestrator control
- Arcade bonus passthrough: orchestrator pushes multiplier to UGS so in-game scoring is affected without modifying game scenes
- Property overrides: `ArcadeGameEntry` reuses `PropertyOverride` resource for per-game tuning without touching game scenes
- Interface Takeover: AO disconnects child Interface from UGS, connects to AO signals. AO is sole source of truth for displayed values. Timer signals stay on UGS for tree walking.
- Scrolling Transitions: Parallel `position:y` tween (0→-360 / 360→0) with cubic ease. AO runs `PROCESS_MODE_ALWAYS` so tweens survive UGS tree pause. `TRANSITIONING` state blocks input.
