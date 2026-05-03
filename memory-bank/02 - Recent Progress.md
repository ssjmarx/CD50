# Recent Progress

**Last Updated:** 2026-05-02

---

## Plan 11 — Modern Tetris (COMPLETE)

All five Modern Tetris features implemented as reusable, toggleable components:

### New Components Created
1. **`ghost_piece.gd`** — Projects piece downward via physics queries, renders transparent outline at landing position. Updates on `moved`, `rotated`, and `fell` signals.
2. **`hold_relay.gd`** — Pure signal relay: `parent.action` → `game.hold_requested`. ~15 lines.
3. **`t_spin_detector.gd`** — SRS 3-corner T-spin detection. Tracks `_last_was_rotation` flag, evaluates 4 diagonal corners on `piece_pre_lock`, classifies as full/mini T-spin. Emits via `game.t_spin_detected`.

### Existing Components Enhanced
4. **`lock_detector.gd`** — Added `max_lock_resets` (Guideline default: 15), `piece_pre_lock` signal (fires before `piece_locked` while multi-cell body still exists), and move/rotation counter that force-locks when exceeded.
5. **`line_clear_monitor.gd`** — Added combo scoring (`_combo_count`), back-to-back multiplier (1.5× for "difficult" clears: Tetris + T-spin), T-spin scoring tables, level multiplier, and `score_type` routing.
6. **`tetromino_spawner.gd`** — Added hold piece support (`enable_hold`, `_held_piece`, `_can_hold`), hold/swap cycle with proper freeze/unfreeze, lock detector disconnect on hold to prevent double-lock.
7. **`tetromino.gd`** — Added `ghost_offsets` array and ghost outline rendering in `_draw()`.

### UGS Signal Updates
- `hold_requested` — Hold relay → spawner communication
- `t_spin_detected(is_t_spin, is_mini)` — T-spin detector → line clear monitor communication

### New Scenes
- `Scenes/Components/ghost_piece.tscn`
- `Scenes/Components/hold_relay.tscn`
- `Scenes/Components/t_spin_detector.tscn`

### Design Decisions
- **Signal flow for hold:** `player_control → body.action → hold_relay → game.hold_requested → spawner._on_hold_requested()` — clean relay, no direct coupling
- **Pre-lock timing:** `piece_pre_lock` fires before `piece_locked` so T-spin detector inspects the multi-cell body before spawner splits it
- **Ghost as component (not entity):** Reuses parent's `_draw()`, no lifecycle management
- **All features toggleable:** Every export has sensible defaults; removing a component from `active_piece_components` disables the feature