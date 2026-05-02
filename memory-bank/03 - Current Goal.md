# Current Goal: CD50 — Gridless Tetris

**Last Updated:** 2026-05-02

---

## Active Task

Decompose `tetromino_formation.gd` into focused single-responsibility components, delete `grid_basic.gd`, and compose a fully playable Tetris game using the gridless physics-based paradigm. Full plan: `planning/10 - Gridless Tetris.md`.

---

## Key Decisions

- **Split on lock:** Multi-cell pieces split into individual cell bodies when they lock
- **Physics-based line clearing:** `line_clear_monitor` scans world-space collision shapes, no grid data structure
- **Keep `tetromino_spawner`:** Spawning complexity (split, attach components, preview, bag) justifies a dedicated component
- **DAS in `grid_movement`:** Not redundant with `player_control` — player_control emits raw held state, DAS transforms held→auto-repeat
- **Simple kick table:** (0,0), (-1,0), (1,0), (0,-1), (-2,0), (2,0)
- **Player control attached to piece:** Standard pattern, removed on lock

---

## Build Order

| Step | Component | Action |
|---|---|---|
| 1 | `grid_movement.gd` | Add DAS exports (additive, default off) |
| 2 | `grid_rotation_advanced.gd` | Create new — offset rotation with wall kicks |
| 3 | `lock_detector.gd` | Create new — floor detection + lock delay |
| 4 | `line_clear_monitor.gd` | Rewrite — physics-based row scanning |
| 5 | `tetromino.gd` | Add `single_cell` export |
| 6 | `tetromino_spawner.gd` | Major update — lock/spawn cycle, bag system, preview, split |
| 7 | `tetris.tscn` | Compose game scene |
| 8 | Delete old | Remove `grid_basic` + `tetromino_formation` |

---

## Files Changed

| File | Action |
|---|---|
| `Scripts/Legs/grid_movement.gd` | Enhancement (add DAS) |
| `Scripts/Legs/grid_rotation_advanced.gd` | Create new |
| `Scripts/Components/lock_detector.gd` | Create new |
| `Scripts/Rules/line_clear_monitor.gd` | Rewrite |
| `Scripts/Flow/tetromino_spawner.gd` | Major update |
| `Scripts/Bodies/tetromino.gd` | Minor update |
| `Scenes/Games/remakes/tetris.tscn` | Create new |
| `Scripts/Flow/grid_basic.gd` | Delete |
| `Scripts/Legs/tetromino_formation.gd` | Delete |

---

## Success Criteria

- Tetris is fully playable as a pure scene assembly (no game script)
- `tetromino_formation.gd` is decomposed into 3+ focused components
- `grid_basic.gd` is deleted — all grid movement is gridless
- Line clearing works via physics queries
- Remix potential: tetrominos can fill gaps in Space Invaders formations, arbitrary components attachable to pieces and settled cells