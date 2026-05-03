# Current Goal

**Last Updated:** 2026-05-02

**Status:** Tetris fully complete (Plans 10–12). No active goal.

---

## Completed: Tetris (Plans 10–12)

Tetris is done. Three phases of work completed:

### Plan 10 — Gridless Tetris
Physics-based grid with no grid data structure. Pieces move, rotate, fall, and lock using collision queries. Line clear detection via physics scans. Bag randomizer (7-bag). Level-based gravity speed table.

### Plan 11 — Modern Tetris
All five Modern Tetris Guideline features:
- ✅ Ghost piece (transparent landing preview)
- ✅ Hold piece (swap active piece to hold box)
- ✅ T-spin detection (SRS 3-corner rule)
- ✅ Enhanced scoring (combo, back-to-back, T-spin, level multiplier)
- ✅ Lock delay move limit (15 resets max)

### Plan 12 — Tetris Juice
Audio and visual polish:
- ✅ 10 procedural sound effects (lock, line clear, level up, rotate, move, game over, hold, T-spin, B2B, hard drop)
- ✅ Score tick-up animation
- ✅ Line flash (NES-style)
- ✅ Smooth collapse tween
- ✅ Brick-style cells with color variation
- ✅ UI frames for next/hold boxes

### Final Polish & Bug Fixes
- ✅ Hard drop sound gating (only fires on actual drop)
- ✅ Ghost piece lingering fix (clear offsets on hold)
- ✅ Grid alignment fix (spawner at row center, playfield origin at wall edge)
- ✅ Preview/hold piece rotation (90° clockwise display)
- ✅ Hold piece juice signals on swap-in

---

## Potential Next Steps

- New game implementation (Pac-Man, Galaga, Frogger, etc.)
- Multi-player Tetris (vs mode)
- Tetris visual feedback (combo counter, T-spin popup text)
- Revisit `asterout.tscn` (broken — needs RingSpawner fix)
- Code quality pass (de-duplicate `_is_cell_occupied()` across 5 grid modules)