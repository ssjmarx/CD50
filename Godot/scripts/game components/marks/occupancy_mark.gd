## occupancy tracker, emits signals when stuff enters and exits
class_name OccupancyMark extends CDMark

@export var tracked_groups: Array[StringName] = []

@export_group("Emit Signals")
@export var on_occupancy_changed: Array[StringName] = [&"occupancy_changed"]

var _counts: Dictionary = {}

func _ready() -> void:
	super._ready()
	for group in tracked_groups:
		_counts[group] = 0

func _on_body_entered(body: Node2D) -> void:
	for group in tracked_groups:
		if body.is_in_group(group):
			_counts[group] = _counts.get(group, 0) + 1
			for sig in on_occupancy_changed:
				game.bus_emit(sig, [group, _counts[group]])

func _on_body_exited(body: Node2D) -> void:
	for group in tracked_groups:
		if body.is_in_group(group):
			_counts[group] = max(_counts.get(group, 0) - 1, 0)
			for sig in on_occupancy_changed:
				game.bus_emit(sig, [group, _counts[group]])

func get_count(group: StringName) -> int:
	return _counts.get(group, 0)
