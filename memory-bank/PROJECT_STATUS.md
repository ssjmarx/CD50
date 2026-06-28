# Project Status — CD50

> **Source of truth for what exists in the codebase.**
> Architecture, component catalogue, and pattern reference.
> Update this file when scripts are added, removed, or renamed.

**Last Updated:** 2026-06-16
**Architecture:** V2 Composable Architecture
**Total V2 Scripts:** 174
**Canonical Reference:** `USAGE.md` (deep guide), `planning/V2 Rules.md`

---

## Architecture Overview

The V2 architecture uses `CDEntity`/`CDEntityComponent`/`CDGameComponent`. Components communicate via entity bus and game bus (both native Godot signals + blackboard). All dynamic signals are zero-arg; data flows through `entity.blackboard` and `game.blackboard`. Processing order is deterministic via priority categories.

### The Three Rules
1. **Composition over inheritance** — CDEntity is a blank physics shell. All behavior comes from components.
2. **Signals, not calls** — Components never call methods on other components. They emit signals.
3. **Single-purpose components** — Each component does one thing. Split if it does two.

### Priority Cascade
