# Cards — Game-State Cue Cards

4 card components that track and display game state. All extend `CDCueCard` (which provides `_update_label()` and label management). Cards are game-level components — they live in the game scene, not on entities, and communicate via the **game bus** rather than entity signals.

---

## Common Card Pattern

```
_ready()              → super._ready(), set initial state, _update_label(), call_deferred("_on_initialize")
_on_initialize()      → game.bus_connect() for all listen signals
_on_<event>()         → update state, _update_label(), game.bus_emit() for emit signals
```

### Must-Includes When Creating Cards

1. Extend `CDCueCard`
2. Call `super._ready()` first in `_ready()`
3. Initialize state vars and call `_update_label()` in `_ready()`
4. Use `call_deferred("_on_initialize")` to connect bus signals after scene tree is ready
5. Use `@export_group("Listen Signals")` for incoming game bus signals
6. Use `@export_group("Emit Signals")` for outgoing game bus signals
7. Use `game.bus_connect(sig, callable)` to listen and `game.bus_emit(sig, [args])` to broadcast

### Game Bus API

| Method | Purpose |
|--------|---------|
| `game.bus_connect(signal_name, callable)` | Subscribe to a game bus signal |
| `game.bus_emit(signal_name)` | Broadcast a signal with no args |
| `game.bus_emit(signal_name, [arg1, ...])` | Broadcast a signal with args |

### CDCueCard Inherited API

| Method | Purpose |
|--------|---------|
| `_update_label(text)` | Update the display label text |

---

## Components

### LivesCard — Player Lives Tracker

Tracks remaining lives. Emits `lives_changed` on every change and `lives_depleted` when lives hit zero.

| Feature | Details |
|---------|---------|
| **Listen** | `life_lost`, `life_gained` |
| **Emit** | `lives_changed(current_lives)`, `lives_depleted()` |
| **State** | `current_lives` (int) |
| **Display** | Integer count |

### ScoreCard — Score + Multiplier Tracker

Tracks score with an optional multiplier. Multiplier is applied when adding score (not when setting). Leave multiplier signal arrays empty to disable multiplier behavior.

| Feature | Details |
|---------|---------|
| **Listen** | `add_score(amount)`, `set_score(new_score)`, `add_multiplier(amount)`, `set_multiplier(new_mult)` |
| **Emit** | `score_changed(current_score)`, `multiplier_changed(current_multiplier)` |
| **State** | `current_score` (int), `current_multiplier` (float) |
| **Display** | Integer score |

### TimerCard — Countdown / Count-Up Timer

Tracks elapsed or remaining time with configurable tick interval. Stops automatically on expiry in COUNT_DOWN mode.

| Feature | Details |
|---------|---------|
| **Listen** | `timer_pause`, `timer_resume`, `timer_reset` |
| **Emit** | `timer_tick(current_time)`, `timer_expired()` |
| **State** | `current_time` (float), `_is_running` (bool) |
| **Display** | Formatted as "M:SS" |
| **Modes** | COUNT_DOWN (stops at 0), COUNT_UP (runs forever) |

### WaveCard — Wave Tracker & Relay

Tracks current wave number. Advances on configurable triggers (e.g. `game_play` + `wave_cleared`). Emits wave number before incrementing so listeners see the correct wave.

| Feature | Details |
|---------|---------|
| **Listen** | `game_play`, `wave_cleared` (advance), `wave_reset` |
| **Emit** | `wave_start(current_wave)`, `wave_changed(current_wave)` |
| **State** | `current_wave` (int) |
| **Display** | "Wave N" |
