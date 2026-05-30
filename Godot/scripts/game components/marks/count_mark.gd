# CountMark
# Tracks unique bodies entering the zone and emits when a target count is reached
# Deduplicates bodies — each body counted only once regardless of re-entry

class_name CountMark extends CDMark

# --- exports ---

# number of unique bodies required to trigger completion
@export var target_count: int = 3

# game bus signals for count changes and completion
@export_group("Emit Signals")
@export var on_count_changed: Array[StringName] = [&"mark_count_changed"]
@export var on_count_reached: Array[StringName] = [&"mark_count_reached"]

# --- state ---

# deduplicated list of bodies that have entered
var _tracked_bodies: Array[Node2D] = []

# --- body detection ---

# track unique bodies, emit count changes and completion
func _on_body_entered(body: Node2D) -> void:
	if not _passes_filter(body):
		return
	
	# relay base entered signal
	for sig in on_entered:
		game.bus_emit(sig, [body])
	
	# only count new bodies
	if body not in _tracked_bodies:
		_tracked_bodies.append(body)
		var current_count := _tracked_bodies.size()
		
		# emit updated count
		for sig in on_count_changed:
			game.bus_emit(sig, [current_count])
		
		# check if target reached
		if current_count >= target_count:
			for sig in on_count_reached:
				game.bus_emit(sig, [_tracked_bodies])

# relay base exited signal (does not decrement count)
func _on_body_exited(body: Node2D) -> void:
	if _passes_filter(body):
		for sig in on_exited:
			game.bus_emit(sig, [body])
