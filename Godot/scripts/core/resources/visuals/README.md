# Visuals Resources

Data-only `Resource` classes that describe **visual configuration** for entity components. No scene-tree logic — pure data containers authored in the inspector and consumed by components at runtime.

## Files

| Class | Purpose | Consumed by |
|-------|---------|-------------|
| `CDFaceBinding` | Pairs an entity-bus signal with a sprite frame index, plus optional timed restore (`restore_after`); `0.0` = permanent switch | Face components' `bindings: Array[CDFaceBinding]` |

---

## Patterns

### 1. Data-only
Every visuals resource is a pure `Resource`: `class_name CD<Name> extends Resource`, `@export` fields with sensible defaults, no `_ready()` / `_process()` / node/scene-tree logic. Behavior lives in the consuming component.

### 2. Self-contained rule shape
A resource in this folder typically reads as a single self-contained rule, e.g. `CDFaceBinding` = *"when this bus signal fires, show this frame, and (optionally) snap back to the default frame after N seconds."*

### 3. Two-line `##` header
Each file starts with `## ClassName` + a one-line description (the in-editor resource description).

### 4. Per-export `##` docs
Every `@export` has a `##` comment, with units/defaults called out where relevant.

---

## How to create a new visuals resource

```gdscript
## CDMyVisualConfig
## One-line description of the visual configuration

class_name CDMyVisualConfig extends Resource

## what this field controls (include units/defaults)
@export var something: int = 0
```

### Checklist

- [ ] New `.gd` file in this folder; `class_name CD<Name> extends Resource`.
- [ ] Two-line `##` header (class name + one-line description).
- [ ] Every configurable field is `@export` with a `##` comment and sensible default.
- [ ] No `_ready()` / `_process()` / scene-tree logic — data in, data out, no side effects.
- [ ] Behavior belongs in the consuming component, not here.