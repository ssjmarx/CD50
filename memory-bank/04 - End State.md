# End State: CD50 — Arcade Cabinet

**Last Updated:** 2026-05-02

---

## Vision

CD50 is a componentized arcade game collection demonstrating that classic arcade games can be built entirely from reusable, composable components — zero game-specific scripts. Every game is a scene assembly.

---

## Final State

- **10 playable games** — Pong, Breakout, Asteroids, Pongsteroids, Dogfight, Pongout, Breaksteroids, Space Invaders, Tetris, Modern Tetris
- **83 components** across 9 categories (Core, Bodies, Brains, Legs, Arms, Components, Rules, Flow, Effects)
- **Zero game scripts** — every game is a `UniversalGameScript` root with attached components
- **Full Tetris suite** — classic Tetris (Plan 10) + Modern Tetris Guideline features (Plan 11): ghost piece, hold piece, T-spin detection, combo/B2B/level scoring, lock delay move limit
- **All features toggleable** — Modern Tetris features are additive components with sensible defaults; existing games unchanged

---

## Architecture Achievements

- Clean signal flow: Brains → Body → Legs/Arms → Components/Rules/Flow → Effects
- UGS as event bus: components communicate through game-level signals (`hold_requested`, `t_spin_detected`, `piece_settled`)
- Physics-based grid: Tetris uses no grid data structure — all detection via physics queries
- Pre-lock timing pattern: `piece_pre_lock` fires before `piece_locked` for pre-lock inspection
- Component toggleability: features enabled/disabled by including/excluding component scenes