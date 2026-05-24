## emits after N unique bodies have entered
class_name CountMark extends CDMark

@export var target_count: int = 3

@export_group("Emit Signals")
@export var on_count_changed: Array[StringName] = [&"mark_count_changed"]
@export var on_count_reached: Array[StringName] = [&"mark_count_reached"]

var _tracked_bodies: Array[Node2D] = []

func _on_body_entered(body: Node2D) -> void:
	if not _passes_filter(body):
		return
	
	for sig in on_entered:
		game.bus_emit(sig, [body])
	
	if body not in _tracked_bodies:
		_tracked_bodies.append(body)
		var current_count := _tracked_bodies.size()
		
		for sig in on_count_changed:
			game.bus_emit(sig, [current_count])
		
		if current_count >= target_count:
			for sig in on_count_reached:
				game.bus_emit(sig, [_tracked_bodies])

func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])
