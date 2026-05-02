# Current Goal: GD50 — Tetris Decomposition & Composition

**Last Updated:** 2026-05-01

---

## Active Task

Decompose the "god component" `tetromino_formation.gd` and recompose Tetris to use the new gridless `grid_movement` paradigm, then compose the full Tetris game scene.

---

## Background

Space Invaders proved that the gridless `grid_movement` refactor works beautifully — invaders step by fixed pixel amounts, no `GridBasic` dependency needed. Now Tetris needs the same treatment.

The current `tetromino_formation.gd` is a monolithic leg component that handles too many responsibilities:
- Multi-cell shape management (offsets array)
- Rotation of offsets
- Landing detection
- Lock delay
- Cell registration in grid occupancy map
- Visual sprite creation on lock
- Interactable followers for remix scenarios

This needs to be decomposed into focused, single-responsibility components that compose together.

---

## Steps

### Step 1: Decompose `tetromino_formation.gd`
Break the god component into separate concerns:
- **Formation/offset management** — tracking which cells a multi-cell body occupies
- **Rotation logic** — rotating the offset array
- **Landing detection** — detecting when a piece can't move further down
- **Lock delay** — timing before a landed piece locks in place
- **Cell registration** — registering locked cells in grid_basic for line clearing

### Step 2: Recompose Tetrominos for Gridless GridMovement
Adapt tetromino entities to use the refactored `grid_movement.gd` (step-based, no GridBasic dependency):
- Tetromino pieces use GridMovement for lateral movement and gravity
- FallingAI emits DOWN moves on a timer
- GridRotation handles discrete 90° rotation

### Step 3: Implement Tetris-Specific Components
New components needed for the decomposed architecture:
- Whatever focused components emerge from the decomposition
- May need new landing/lock detection that works with the gridless paradigm

### Step 4: Compose Tetris Game Scene
Assemble `Scenes/Games/remakes/tetris.tscn` from:
- UniversalGameScript root
- TetrominoSpawner (bag/queue)
- GridBasic (for line-clear detection only, not movement)
- LineClearMonitor
- FallingAI + GridMovement + GridRotation on tetromino bodies
- Timer for gravity speed
- LivesCounter or equivalent game-over condition
- Interface for score/next piece display

---

## Dependencies & Risks

- `grid_basic.gd` is still needed for **line clearing** (occupancy tracking, row detection) even though movement no longer depends on it
- The decomposition must preserve remix compatibility — tetromino_formation's "interactable followers" feature needs to survive in some form
- Tetris has stricter grid requirements than Space Invaders (pieces must align perfectly to cell boundaries)
- Lock delay timing is critical for playability — too fast feels punishing, too slow feels floaty

---

## Related Files

| File | Role |
|------|------|
| `Scripts/Legs/tetromino_formation.gd` | God component to decompose |
| `Scripts/Legs/grid_movement.gd` | Gridless movement (already refactored for Space Invaders) |
| `Scripts/Legs/grid_rotation.gd` | Discrete rotation (may need updates) |
| `Scripts/Brains/falling_ai.gd` | Gravity brain (should work as-is) |
| `Scripts/Flow/tetromino_spawner.gd` | Piece spawning (may need updates) |
| `Scripts/Rules/line_clear_monitor.gd` | Line clearing (depends on grid_basic) |
| `Scripts/Flow/grid_basic.gd` | Grid occupancy (still needed for line clearing) |
| `Scripts/Bodies/tetromino.gd` | Body drawing code |
| `planning/07 - Space Invaders and Tetris.md` | Original planning document |

---

## Success Criteria

- Tetris is fully playable as a pure scene assembly (no game script)
- `tetromino_formation.gd` is decomposed into focused single-responsibility components
- All tetromino movement uses the gridless `grid_movement` paradigm
- Line clearing works correctly via `grid_basic` + `line_clear_monitor`
- The component architecture remains clean and remix-friendly