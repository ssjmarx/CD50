## CountMark
## Produces: a count_reached game bus signal when N unique bodies enter the zone.
## Consumes: bodies entering/exiting the zone Area2D.

class_name CountMark extends CDMark

## --- exports ---

## number of unique bodies required to trigger completion
@export var target_count: int = 3

@export_group("Blackboard Keys")
## key for writing current unique body count to game blackboard (int)
@export var count_key: StringName = &"mark_count"
## key for writing the tracked bodies array when target reached (Array[Node2D])
@export var bodies_key: StringName = &"mark_bodies"

## game bus signals for count changes and completion (zero-arg)
@export_group("Emit Signals")
@export var on_count_changed: Array[StringName] = [&"mark_count_changed"]
@export var on_count_reached: Array[StringName] = [&"mark_count_reached"]

## --- state ---

## deduplicated list of bodies that have entered
var _tracked_bodies: Array[Node2D] = []

## track unique bodies, write to blackboard, emit zero-arg signals
func _handle_body_entered(body: Node2D) -> void:
	## base enter behavior: write entered body key + emit enter signals
	super._handle_body_entered(body)

	if body not in _tracked_bodies:
		_tracked_bodies.append(body)
		var current_count := _tracked_bodies.size()

		game.blackboard[count_key] = current_count
		for sig in on_count_changed:
			game.bus_emit(sig)

		## check if target reached
		if current_count >= target_count:
			game.blackboard[bodies_key] = _tracked_bodies.duplicate()
			for sig in on_count_reached:
				game.bus_emit(sig)

## relay base exit behavior (does not decrement count)
func _handle_body_exited(body: Node2D) -> void:
	super._handle_body_exited(body)
