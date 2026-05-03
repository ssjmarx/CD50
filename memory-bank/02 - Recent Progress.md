# Recent Progress

**Last Updated:** 2026-05-02

---

## Tetris Final Polish & Bug Fixes (COMPLETE)

Closing fixes after Plans 10–12 to call Tetris "done."

### Bug Fixes
1. **Hard drop sound gating** — Hard drop sound fired on every key press instead of only when a drop actually occurred. Added `signal hard_dropped` to `grid_movement.gd` (only emits when `total_displacement != Vector2.ZERO`). Updated `tetromino_spawner.gd` to listen for `hard_dropped` instead of `piece.shoot`.
2. **Ghost piece lingering** — Hold piece's ghost offsets persisted when moved to hold box, projecting a ghost from the hold position back onto the playfield. Fixed by clearing `ghost_offsets` and calling `queue_redraw()` in `_position_hold_piece()`.
3. **Hold piece missing juice signals** — `_swap_in_held_piece()` didn't call `_connect_piece_signals()`, so swapped-in pieces had no move/rotate/drop sounds. Added the call.
4. **Grid alignment gap** — Spawner y-position was at row edge (18) instead of row center (27), causing a half-cell gap between where pieces land and where `line_clear_monitor` scans. Fixed in `tetris.tscn`: spawner `(338, 27)`, `playfield_origin.x = 239`.
5. **Unused export cleanup** — Removed unused `margin` export from `line_clear_monitor.gd`.

### Visual Touches
6. **Preview/hold rotation** — Preview and hold pieces display rotated 90° clockwise; rotation resets to 0 when pieces become active.

### Scripts Modified
- **`grid_movement.gd`** — Added `signal hard_dropped`, emit only on actual drop
- **`tetromino_spawner.gd`** — Switch to `hard_dropped` signal; ghost offset cleanup in `_position_hold_piece()`; `_connect_piece_signals()` in `_swap_in_held_piece()`; preview/hold rotation (PI/2) with active reset (0)
- **`line_clear_monitor.gd`** — Removed unused `margin` export

---

## Plan 12 — Tetris Juice (COMPLETE)

Audio and visual enhancements for the Tetris remake. All features implemented as reusable enhancements.

### Sound Effects (10 instances via `sound_synth.tscn` ON_SIGNAL mode)
1. **Lock thunk** — Square/DECAY/C3, 0.08s (via `piece_did_lock`)
2. **Line clear chirp** — Square/DECAY/E4, 0.12s (via `lines_cleared`)
3. **Level up jingle** — Sine/WARBLE/E5, 0.3s (via `level_changed`)
4. **Rotate click** — Triangle/DECAY/C5, 0.03s (via `piece_rotated`)
5. **Move tick** — Noise/DECAY/C4, 0.02s (via `piece_moved`)
6. **Game over descend** — Sine/SWEEP_DOWN/C4, 1.5s (via `state_changed` filter "2")
7. **Hold whoosh** — Noise/SWEEP_DOWN/A4, 0.1s (via `hold_requested`)
8. **T-spin ding** — Sine/WARBLE/E5, 0.2s (via `t_spin_detected` filter "true")
9. **B2B chime** — Sine/WARBLE/G5, 0.15s (via `back_to_back`)
10. **Hard drop thunk** — Square/DECAY/C3, 0.06s (via `piece_hard_dropped`)

### Visual Effects
1. **Score tick-up** — `interface.gd` now animates score values counting up over 0.3s (global, benefits all games)
2. **Line flash** — Cleared rows flash white 3 times during the 0.3s clear delay (NES-style)
3. **Smooth collapse** — Remaining rows ease-in tween downward over 0.1s instead of snapping
4. **Brick-style cells** — 3D cube effect with highlight (top-left) and shadow (bottom-right) edges + per-cell color variation
5. **UI frames** — Next piece box, hold piece box, playfield top/bottom borders drawn as ColorRects

### Scripts Modified
- **`interface.gd`** — Added `animate_score`, `score_animation_duration` exports; `_animate_score()` helper with tween management
- **`tetromino_spawner.gd`** — Added `piece_moved`, `piece_rotated`, `piece_hard_dropped` relay signals; `_connect_piece_signals()` method
- **`line_clear_monitor.gd`** — Added `enable_line_flash`, `enable_smooth_collapse`, `collapse_duration` exports; `_flash_rows()`, `_get_bodies_in_rows()` methods; modified `_collapse_rows()` with tween support; added `back_to_back` signal
- **`tetromino.gd`** — Added `brick_style`, `color_variation` exports; `_draw_brick()`, `_get_cell_color()`, `_regenerate_color_seeds()` methods
- **`sound_synth.gd`** — Fixed `_on_signal` filter to use `str(arg1)` for non-string signal payloads

### Design Decisions
- **Signal relay pattern:** `tetromino_spawner` relays piece-level events as game-level signals so sounds can connect to stable nodes (spawner doesn't change between pieces)
- **No new components needed:** All sounds use existing `sound_synth.tscn` instances wired in the scene
- **Global improvements:** Score tick-up applies to all games via `interface.gd`; line flash/collapse are toggleable exports

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
