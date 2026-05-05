# End State: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-04

---

## Vision

CD50 is a componentized arcade game collection demonstrating that classic arcade games can be built entirely from reusable, composable components — zero game-specific scripts. Every game is a scene assembly. The project ships as an itch.io arcade cabinet with a meta-level orchestrator that runs games in sequence with fast rules, lives, and cumulative scoring.

---

## Final State

- **8 playable games** — Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Space Invaders, Tetris (Modern), Breaksteroids
- **89 components** across 10 categories (Core, Bodies, Brains, Legs, Arms, Components, Rules, Flow, Effects, Hub)
- **Zero game scripts** — every game is a `UniversalGameScript` root with attached components
- **Full Tetris suite** — Physics-based grid (Plan 10), Modern Tetris Guideline features (Plan 11): ghost piece, hold piece, T-spin detection, combo/B2B/level scoring, lock delay move limit. Juice and polish (Plan 12): 10 procedural sounds, score tick-up, line flash, smooth collapse, brick-style cells.
- **Arcade orchestrator** — Boot → shuffle playlist → play games with fast rules → track lives/score/multiplier → game over → replay. 7 tuned game entries for 15–45s arcade pacing.
- **All features toggleable** — Modern Tetris features are additive components with sensible defaults; existing games unchanged

---

## Architecture Achievements

- Clean signal flow: Brains → Body → Legs/Arms → Components/Rules/Flow → Effects
- UGS as event bus: components communicate through game-level signals (`hold_requested`, `t_spin_detected`, `piece_settled`)
- Physics-based grid: Tetris uses no grid data structure — all detection via physics queries
- Pre-lock timing pattern: `piece_pre_lock` fires before `piece_locked` for pre-lock inspection
- Component toggleability: features enabled/disabled by including/excluding component scenes
- UGS Mode enum: STANDALONE vs ARCADE — same game scenes work standalone or under orchestrator control
- Arcade bonus passthrough: orchestrator pushes multiplier to UGS so in-game scoring is affected without modifying game scenes
- Property overrides: `ArcadeGameEntry` reuses `PropertyOverride` resource for per-game tuning without touching game scenes