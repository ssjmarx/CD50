# Current Goal

**Last Updated:** 2026-05-03  
**Status:** Active — Plan 13 (Arcade Orchestrator) — finishing remaining items

---

## Active Plan: 13 — Arcade Orchestrator

Building the architecture for an itch.io arcade demo: a meta-level orchestrator that loads existing games in sequence, runs them with fast rules, tracks lives and score across the run, and provides a complete boot → play → game over → replay loop.

### Completion Status

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 0 | Input Refactoring | ✅ COMPLETE |
| Phase 1 | Shell (boot, orchestrator, one game in/out) | ✅ COMPLETE |
| Phase 2 | The Run (lives, sequence, score, game over) | ~90% — transitions and preloading remaining |
| Phase 3 | Fast Rules (per-game overrides, tuning) | ✅ COMPLETE |

### Remaining Work

1. **Scrolling transitions** — Currently games load/free instantly. Plan calls for: next game instanced below viewport, tween current game up/off while new game scrolls in (0.4s cubic ease), then free old game.
2. **Preloading** — `ResourceLoader.load_threaded_request()` for next entry's scene during gameplay, `load_threaded_get()` on transition. Fallback: "LOADING" text and poll.

### What's Already Built

- **ArcadeOrchestrator** (`Scripts/Hub/arcade_orchestrator.gd`) — Full state machine (BOOT → PLAYING → RESULT → GAME_OVER), shuffle bag, lives, score carry, time bonus, per-game multiplier
- **ArcadeGameEntry** (`Scripts/Hub/arcade_game_entry.gd`) — Resource: PackedScene + PropertyOverride array
- **UGS Mode enum** — STANDALONE vs ARCADE, Interface suppression, arcade bonus passthrough
- **7 tuned game entries** — Pong, Asteroids, Tetris, Breakout, Space Invaders, Pongsteroids, Dogfight
- **Boot screen + Game Over screen** — Functional with start/coin input
- **Input refactoring** — `start`, `coin`, `pause` in Input Map; `player_control.gd` and UGS fully refactored

---

## Future Phases (Post-Plan 13)

- Phase 4 — Polybius face + voice + dialogue
- Phase 5 — Scoreboard with local high scores
- Phase 5.5 — Kill screen secret + code entry
- Phase 6 — Juice: CRT, sounds, animations
- Phase 7 — Ship: itch.io export