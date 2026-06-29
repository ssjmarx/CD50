# Project Status — CD50

> **Source of truth for what exists in the codebase.**
> Architecture, component catalogue, and pattern reference.
> Update this file when scripts are added, removed, or renamed.

**Last Updated:** 2026-06-28
**Architecture:** V2 Composable Architecture
**Total V2 Scripts:** 191
**Canonical Reference:** `USAGE.md` (deep guide), `planning/V2 Rules.md`

> **Recent change (cleanup):** removed duplicate director/manager pairs — `state_director.gd` and `signal_sequence_director.gd` were deleted as near-duplicates of `managers/state_manager.gd` and `managers/signal_manager.gd`. Current `game components/` counts: cards 5, directors 6, managers 4, goals 3, marks 6, projectors 3 (includes `cd_game_control.gd` base), speakers 3, trapdoors 3. See `CONVENTIONS.md` for the manager-vs-director boundary.

---

## Architecture Overview

The V2 architecture uses `CDEntity`/`CDEntityComponent`/`CDGameComponent`. Components communicate via entity bus and game bus (both native Godot signals + blackboard). All dynamic signals are zero-arg; data flows through `entity.blackboard` and `game.blackboard`. Processing order is deterministic via priority categories.

### The Three Rules
1. **Composition over inheritance** — CDEntity is a blank physics shell. All behavior comes from components.
2. **Signals, not calls** — Components never call methods on other components. They emit signals.
3. **Single-purpose components** — Each component does one thing. Split if it does two.

### Priority Cascade
