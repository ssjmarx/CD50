# 12 — Tetris Juice

Audio and visual enhancements for the Tetris remake, organized by implementation order. Reuses existing components (`sound_synth`, `interface`, `death_effect`) and signal flows wherever possible.

---

## Signal Map (Available Hooks)

All juice connects to these existing signals — no new signals needed for most features:

| Source Component | Signal | Payload |
|---|---|---|
| `lock_detector` | `piece_locked` | `cell_positions: Array[Vector2]` |
| `lock_detector` | `lock_cancelled` | — |
| `grid_movement` | `moved` | — |
| `grid_rotation_advanced` | `rotated` | — |
| `line_clear_monitor` | `lines_cleared` | `count: int, row_indices: Array[int]` |
| `line_clear_monitor` | `level_changed` | `new_level: int` |
| `line_clear_monitor` | `score_gained` | `points: int` |
| `line_clear_monitor` | `back_to_back` | — |
| `t_spin_detector` | `t_spin_detected` | `is_t_spin: bool, is_mini: bool` |
| `tetromino_spawner` | (game) `piece_settled` | — |
| `tetromino_spawner` | (game) `spawn_next` | — |
| `hold_relay` | (game) `piece_held` | — |
| `universal_game_script` | `on_points_changed` | `new_score` |

---

## Phase 1 — Sound Effects (sound_synth instances)

All sounds use the existing `sound_synth.tscn` in ON_SIGNAL mode. Each is a scene instance placed in the Tetris game scene, wired to a signal source.

### 1.1 Piece Lock Thunk
- **Sound:** Low square wave, DECAY effect, short duration (~0.08s), note C3
- **Wiring:** `source_node` → LockDetector, `source_signal` → "piece_locked"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, SQUARE, DECAY, C3, vol=0.15, dur=0.08)

### 1.2 Line Clear Chirp
- **Sound:** Quick ascending square wave blip, SWEEP_DOWN or DECAY, note E4→G4, ~0.12s
- **Wiring:** `source_node` → LineClearMonitor, `source_signal` → "lines_cleared"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, SQUARE, DECAY, E4, vol=0.2, dur=0.12)

### 1.3 Level Up Jingle
- **Sound:** 3-4 note ascending arpeggio. Could be achieved with a new `sound_arpeggio` component, or chain multiple sound_synth instances with staggered delays. Simplest: a dedicated jingle component.
- **Wiring:** `source_node` → LineClearMonitor, `source_signal` → "level_changed"
- **Component:** New `sound_arpeggio.tscn` — plays a rapid sequence of notes from an export array. **Reusable for all games.**

### 1.4 Rotate Click
- **Sound:** Tiny triangle wave tick, DECAY, note C5, ~0.03s, very quiet
- **Wiring:** `source_node` → GridRotationAdvanced, `source_signal` → "rotated"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, TRIANGLE, DECAY, C5, vol=0.05, dur=0.03)

### 1.5 Move Tick
- **Sound:** Even tinier noise tick, ~0.02s, very quiet
- **Wiring:** `source_node` → GridMovement, `source_signal` → "moved"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, NOISE, DECAY, C4, vol=0.03, dur=0.02)

### 1.6 Game Over Descend
- **Sound:** Long SWEEP_DOWN sine wave, ~1.5s, note C4→C2
- **Wiring:** `source_node` → Game (UGS), `source_signal` → "state_changed", `filter_value` → "GAME_OVER"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, SINE, SWEEP_DOWN, C4, vol=0.3, dur=1.5)

### 1.7 Hold Whoosh
- **Sound:** Short noise burst with SWEEP_DOWN, ~0.1s
- **Wiring:** `source_node` → Game (UGS), `source_signal` → "piece_held"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, NOISE, SWEEP_DOWN, A4, vol=0.1, dur=0.1)

### 1.8 T-Spin Ding
- **Sound:** Bright sine chime, WARBLE effect, note E5, ~0.2s
- **Wiring:** `source_node` → TSpinDetector, `source_signal` → "t_spin_detected", `filter_value` → "true"
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, SINE, WARBLE, E5, vol=0.25, dur=0.2)

### 1.9 Back-to-Back Chime
- **Sound:** Higher-pitched version of T-spin ding, or a quick two-note arpeggio
- **Wiring:** This requires knowing B2B state from `line_clear_monitor`. Options:
  - A: Add a `back_to_back` signal to `line_clear_monitor` (emits when B2B activates)
  - B: Create a `sound_b2b.tscn` component that listens to `score_gained` and tracks B2B
- **Recommendation:** Option A — ✅ Done. `back_to_back` signal added to `line_clear_monitor`
- **Component:** `sound_synth.tscn` instance (ON_SIGNAL, SINE, WARBLE, G5, vol=0.25, dur=0.15)

---

## Phase 2 — Visual Effects

### 2.1 Line Flash Before Clear (NES Style)
- **Behavior:** When `lines_cleared` fires, flash the cells in those rows white 2-3 times over ~0.3s, THEN clear
- **Implementation:** Modify `line_clear_monitor._check_and_clear()` — between detecting full rows and calling `_clear_rows()`, run a flash tween on the bodies in those rows
- **Alternative:** New `line_flash.tscn` component (Flow/) that listens to `lines_cleared` signal and tweens the bodies' modulate before the clear delay expires
- **Recommendation:** Modify `line_clear_monitor` directly — the `clear_delay` pause already exists and is the right place for the flash animation

### 2.2 Score Tick-Up (Global Interface Enhancement)
- **Behavior:** When score changes, animate the displayed number counting up rapidly instead of appearing instantly
- **Implementation:** Modify `interface.gd`'s `set_points()`, `set_p1_score()`, `set_p2_score()` to use a tween that counts from old value to new value over ~0.3s
- **Scope:** This applies globally to all games using the interface component — exactly as requested
- **New exports on interface:** `animate_score: bool = true`, `score_animation_duration: float = 0.3`

### 2.3 Line Collapse Animation
- **Behavior:** After rows are cleared, remaining rows above drop smoothly instead of snapping
- **Implementation:** Modify `line_clear_monitor._collapse_rows()` — instead of directly setting `body.global_position.y`, tween each body downward over ~0.15s
- **Concern:** The `await create_timer(clear_delay)` already exists; the collapse can happen as a tween after that
- **Alternative:** Keep the instant collapse but add a brief ease-out tween per body

### 2.4 Next Piece Box / Board Frame
- **Behavior:** Drawn UI elements around the playfield
- **Implementation:** These are scene-level additions to `tetris.tscn` — either:
  - A: Drawn in Godot using `ColorRect` / `Line2D` / custom drawing
  - B: Made with Kenney assets
- **User preference:** Try drawn version first
- **Next piece box:** A Control node positioned next to the playfield, updated when `spawn_next` fires
- **Board frame:** A `Panel` or drawn `Control` around the playfield area

### 2.5 Tetromino Brick Style (Cube Effect)
- **Behavior:** Each settled cell looks like a small 3D cube instead of a flat colored square. Randomized color variation within a palette.
- **Implementation:** Modify the settled cell scene OR the tetromino's cell drawing:
  - Add highlight (top-left edges brighter) and shadow (bottom-right edges darker) to each cell
  - Randomize the base color slightly per cell (±hue/saturation variation within the piece's color)
- **Exports:** `brick_style: bool = true`, `color_palette: String = "warm"` (warm/cool/neutral)
- **Palettes:**
  - Warm: reds, oranges, yellows — slight random variation in saturation/brightness
  - Cool: blues, teals, purples — same variation
  - Each piece type keeps its base hue, but individual cells get ±10% variation

---

## Phase 3 — Optional Enhancements (Future)

These are documented for later consideration:

- **Hard drop trail** — brief afterimage from start to end position
- **Lock delay flash** — piece modulate pulses as lock timer expires
- **T-spin notification** — floating text "T-Spin!" that scales up and fades
- **Screen shake on hard drop** — 2-3px camera shake
- **Combo counter display** — "3 COMBO" animated text
- **Particle burst on line clear** — sparks from cleared rows
- **Perfect clear celebration** — full screen flash when board empties

---

## Implementation Order

Recommended sequence, each buildable and testable independently:

1. **Score tick-up** (interface.gd modification — global, benefits all games)
2. **Piece lock thunk** (simplest sound, validates the sound_synth wiring pattern)
3. **Line clear chirp** (second sound, proves multi-sound coexistence)
4. **Rotate click + Move tick** (subtle, completes the "feel" layer)
5. **Hold whoosh** (validates game-level signal wiring)
6. **T-spin ding** (validates filter_value usage)
7. **Line flash before clear** (first visual effect, most iconic)
8. **Line collapse animation** (builds on flash timing)
9. **Tetromino brick style** (biggest visual change)
10. **Next piece box + board frame** (scene-level UI work)
11. **Game over descend** (needs longer duration sound_synth testing)
12. **Level up jingle** (may need new arpeggio component)
13. **Back-to-back chime** (requires line_clear_monitor signal addition)

---

## New Components Needed

| Component | Type | Reusable? | Purpose |
|---|---|---|---|
| `sound_arpeggio.tscn` | Flow | ✅ All games | Play a sequence of notes rapidly (level-up jingles, fanfares) |

Everything else reuses `sound_synth.tscn` or modifies existing scripts (interface, line_clear_monitor, tetromino).