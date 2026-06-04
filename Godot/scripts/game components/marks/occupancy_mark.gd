## OccupancyMark
## Tracks per-group body counts inside the zone and emits on every change
## Useful for monitoring how many entities of each type occupy an area

class_name OccupancyMark extends CDMark

## --- exports ---

## groups to track occupancy for (each gets its own counter)
@export var tracked_groups: Array[StringName] = []

@export_group("Blackboard Keys")
## key for writing the changed group name to game blackboard (StringName)
@export var changed_group_key: StringName = &"mark_changed_group"
## key for writing the changed group's count to game blackboard (int)
@export var changed_count_key: StringName = &"mark_changed_count"

## game bus signals emitted when any group count changes (zero-arg)
@export_group("Emit Signals")
@export var on_occupancy_changed: Array[StringName] = [&"occupancy_changed"]

## --- state ---

## per-group body count {group_name: int}
var _counts: Dictionary = {}

## --- lifecycle ---

## initialize counters for all tracked groups
func _ready() -> void:
	super._ready()
	for group in tracked_groups:
		_counts[group] = 0

## --- body detection ---

## increment group counters when matching bodies enter
func _on_body_entered(body: Node2D) -> void:
	for group in tracked_groups:
		if body.is_in_group(group):
			_counts[group] = _counts.get(group, 0) + 1
			game.blackboard[changed_group_key] = group
			game.blackboard[changed_count_key] = _counts[group]
			for sig in on_occupancy_changed:
				game.bus_emit(sig)

## decrement group counters when matching bodies exit
func _on_body_exited(body: Node2D) -> void:
	for group in tracked_groups:
		if body.is_in_group(group):
			_counts[group] = max(_counts.get(group, 0) - 1, 0)
			game.blackboard[changed_group_key] = group
			game.blackboard[changed_count_key] = _counts[group]
			for sig in on_occupancy_changed:
				game.bus_emit(sig)

## --- query ---

## return the current occupancy count for a given group
func get_count(group: StringName) -> int:
	return _counts.get(group, 0)