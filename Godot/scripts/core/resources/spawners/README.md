# Spawner Resources — Spawn Configuration

Data-only `Resource` classes that configure **how entities are placed** and **what initial state they receive**. No spawning logic lives here — no `instantiate()`, timers, or loops. These are pure data containers read by trapdoors and arms.

> Consumer code is in `game components/trapdoors/` and `entity components/arms/`, plus `core/base classes/cd_stage_trapdoor.gd`.

## Files

| Concern | Classes | Purpose |
|---------|---------|---------|
| Grid formation definitions | `CDGridLayout`, `CDGridRow`, `CDGridEquation` | Describe *where* things spawn in a grid |
| Spawned-entity initial state | `CDSpawnContext` | Describe *what state* a spawned entity starts with |

| Class | Purpose |
|-------|---------|
| `CDGridEquation` | Uniform grid with probabilistic skips — `columns`/`rows`/`skip_chance`/`min_skips_per_row`; read by `grid_trapdoor` Mode B |
| `CDGridLayout` | Hand-crafted grid of `CDGridRow`s; each cell is a `PackedScene` or `null`; `get_spawn_count()` / `get_cell(index)`; read by `grid_trapdoor` Mode A |
| `CDGridRow` | One row of `PackedScene` cells (`null` = gap); authored/edited independently |
| `CDSpawnContext` | Initial velocity / rotation / randomization / extra groups, applied via `CDUtilities.apply_spawn_context(entity, context)`; optional everywhere it's exposed |

---

## Patterns

### 1. Two distinct concerns
1. **Grid formation definitions** — `CDGridLayout` + `CDGridRow` (authored cell-by-cell) or `CDGridEquation` (uniform grid with skip rules).
2. **Spawned-entity initial state** — `CDSpawnContext`, applied just before an entity enters the tree so a single `PackedScene` can be reused with different starting state.

### 2. Data-only
Every script is a pure `Resource`: `class_name CD<PascalName> extends Resource`, exported fields, optionally small read-only helpers (`CDGridLayout.get_spawn_count()` / `get_cell(index)`). **No node lifecycle, no spawning side effects.**

### 3. Two-line `##` header
Class name on line 1, one-line purpose on line 2.

### 4. Per-export `##` docs
Every `@export var` has a `##` comment above it, with units in parentheses where relevant (e.g. "radians").

### 5. Optional everywhere
`CDSpawnContext` is exposed as an optional `@export` on spawners; consumers null-guard `CDUtilities.apply_spawn_context(spawned, spawn_context)`.

### 6. Consumer wiring
Resources are exposed as `@export var` on consuming nodes (`grid_trapdoor.layout`/`.equation`, trapdoor/arm `spawn_context`) and read from there — never call Godot node lifecycle code from these resources.

---

## How to add a new resource type here

```gdscript
## CDMyNewConfig
## One-line description of what this configures

class_name CDMyNewConfig extends Resource

## what this field controls (include units)
@export var some_value: float = 0.0
```

### Checklist

- [ ] Filename `cd_<snake_case>.gd`; `class_name CD<PascalName> extends Resource`.
- [ ] Two-line `##` header: class name + one-line purpose.
- [ ] Every `@export` has a `##` doc comment (units where relevant).
- [ ] No `instantiate()` / timers / spawning loops / node lifecycle — pure data (small read-only helpers like `get_cell` are fine).
- [ ] If the class needs to actually spawn, it belongs in `game components/trapdoors/` or `entity components/arms/`, not here.
- [ ] Wire it up as an `@export` on the consuming node and read it from there.