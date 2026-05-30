# Goals — Win/Lose Condition Components

2 goal components that detect when a game condition is met and emit signals on the game bus. All extend `CDGameComponent`. Goals are fire-once-or-repeatable triggers that drive game state transitions (victory, defeat, etc.).

---

## Common Goal Pattern

```
_ready()              → set component_category = RULES, super._ready()
_on_initialize()      → connect listen signals to game bus or group registry
_on_<event>()         → compare current value against threshold, emit if met
_compare(observed)    → match comparison enum, return bool
```

### Must-Includes When Creating Goals

1. Extend `CDGameComponent`
2. Set `component_category = CDEnums.ComponentCategory.RULES` in `_ready()`
3. Use `@export_group("Emit Signals")` for signals broadcast when condition is met
4. Use `@export_group("Listen Signals")` for signals that feed data into the goal
5. Use `CDEnums.CountComparison` for the comparison operator
6. Implement `_compare(observed: int) -> bool` with match on all enum cases
7. Guard against re-emission if the goal should only fire once (add `_triggered` flag)

### Comparison Operators

| Enum Value | Meaning |
|------------|---------|
| `LESS_THAN` | observed < target |
| `EQUAL_TO` | observed == target |
| `GREATER_THAN` | observed > target |
| `LESS_OR_EQUAL` | observed <= target |
| `GREATER_OR_EQUAL` | observed >= target |

---

## Components

### GroupCountGoal — Entity Count Condition

Monitors group sizes and triggers when entity counts match a comparison. Can require all groups to match (AND) or any group to match (OR).

| Feature | Details |
|---------|---------|
| **Data source** | `game.group_registry.group_count_changed` signal |
| **Targets** | Multiple groups via `target_groups` array |
| **Logic** | `require_all_groups = true` → AND, `false` → OR |
| **Emit** | `on_count_changed(count)` on every change, `on_condition_met` when comparison passes |

### ScoreThresholdGoal — Score Threshold Condition

Monitors score via game bus and triggers when score crosses a threshold.

| Feature | Details |
|---------|---------|
| **Data source** | Game bus `score_changed` signal |
| **Targets** | Single score value |
| **Comparison** | Configurable via `CDEnums.CountComparison` |
| **Emit** | `on_condition_met` when comparison passes |
