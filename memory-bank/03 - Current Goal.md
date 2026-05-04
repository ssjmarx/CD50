# Current Goal

**Last Updated:** 2026-05-03  
**Status:** Active — Plan 13 (Arcade Orchestrator)

---

## Active Plan: 13 — Arcade Orchestrator and Related Components

Building the architecture for an itch.io arcade demo: a meta-level orchestrator that loads existing games in sequence, runs them with fast rules, tracks lives and score across the run, and provides a complete boot → play → game over → replay loop.

### Phases

- **Phase 0 — Input Refactoring** (Prerequisite): Move all input handling to Godot's Input Map. Add `start`, `coin`, `pause` actions. Refactor `player_control.gd` and `ugs._unhandled_input` to be fully Input Map-driven.
- **Phase 1 — Shell**: Boot screen, orchestrator state machine, load one game (Pong), detect game end, read score. UGS Mode enum (STANDALONE/ARCADE).
- **Phase 2 — The Run**: Lives system, game sequence, preloading, scrolling transitions, score carry + streak multiplier, game over screen.
- **Phase 3 — Fast Rules**: Arcade-specific property overrides per game (15-45s per game), tuning pass.

### Key Architecture Decisions

- **UGS Mode enum** — `STANDALONE` (existing behavior) vs `ARCADE` (suppresses Interface calls, no direct input, orchestrator-controlled)
- **New directory** — `Scripts/Hub/` and `Scenes/Hub/` for meta-level scripts and scenes
- **ArcadeGameEntry** — Reuses existing `PropertyOverride` resource for fast-rule configuration
- **Win/loss detection** — Orchestrator listens to UGS `victory`/`defeat` signals directly
- **Input routing** — All input flows through Input Map actions, no more `_unhandled_input`

### New Scripts/Scenes to Create

- `Scripts/Hub/arcade_orchestrator.gd`
- `Scripts/Hub/arcade_game_entry.gd` (resource)
- `Scripts/Hub/arcade_playlist.gd` (resource)
- `Scripts/Hub/input_router.gd` (or inline in UGS)
- `Scenes/Hub/arcade_orchestrator.tscn`
- `Scenes/Hub/boot_screen.tscn`

### Scripts to Modify

- `universal_game_script.gd` — Mode enum, suppress Interface in ARCADE, remove `_unhandled_input`
- `player_control.gd` — Remove `_unhandled_input`, use `Input.is_action_just_pressed()` in `_physics_process`
- `project.godot` — Add `start`, `coin`, `pause` Input Map actions

---

## Future Phases (Post-Plan 13)

- Phase 4 — Polybius face + voice + dialogue
- Phase 5 — Scoreboard with local high scores
- Phase 5.5 — Kill screen secret + code entry
- Phase 6 — Juice: CRT, sounds, animations
- Phase 7 — Ship: itch.io export