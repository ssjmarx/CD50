# Current Goal

**Last Updated:** 2026-05-02

**Status:** Modern Tetris (Plan 11) is **COMPLETE**. No active goal.

---

## Completed: Modern Tetris (Plan 11)

All five Modern Tetris Guideline features implemented:
- ✅ Ghost piece (transparent landing preview)
- ✅ Hold piece (swap active piece to hold box)
- ✅ T-spin detection (SRS 3-corner rule)
- ✅ Enhanced scoring (combo, back-to-back, T-spin, level multiplier)
- ✅ Lock delay move limit (15 resets max)

All features are toggleable via component inclusion and exports. The existing Tetris game continues to work unchanged (new exports default to disabled). To create a Modern Tetris scene, add ghost_piece, hold_relay, and t_spin_detector to `active_piece_components` and enable the enhanced scoring exports on `line_clear_monitor`.

---

## Potential Next Steps

- Create a dedicated `modern_tetris.tscn` scene with all features enabled
- Add visual feedback for T-spin and combo (UI text popups)
- Implement next-piece queue (3+ piece preview instead of 1)
- Add wall kick refinement (SRS full kick tables per rotation state)
- Revisit `asterout.tscn` (broken — needs RingSpawner fix)