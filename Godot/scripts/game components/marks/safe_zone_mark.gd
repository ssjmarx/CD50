## SafeZoneMark
## Produces: zone_safe/zone_unsafe game bus signals on safety state transitions.
## Consumes: bodies entering/exiting the zone Area2D.

class_name SafeZoneMark extends CDMark

## --- exports ---

## groups that make the zone unsafe when present
@export var unsafe_groups: Array[StringName] = [&"enemies"]

## game bus signals for zone safety transitions (zero-arg)
@export_group("Emit Signals")
@export var on_zone_safe: Array[StringName] = [&"zone_safe"]
@export var on_zone_unsafe: Array[StringName] = [&"zone_unsafe"]

## --- state ---

## count of unsafe bodies currently inside the zone
var _unsafe_count: int = 0

## increment unsafe count and emit unsafe on first entry (replaces base enter)
func _handle_body_entered(body: Node2D) -> void:
	for group in unsafe_groups:
		if body.is_in_group(group):
			var was_safe := _unsafe_count == 0
			_unsafe_count += 1
			## transition from safe to unsafe
			if was_safe:
				for sig in on_zone_unsafe:
					game.bus_emit(sig)
			return

## decrement unsafe count and emit safe when cleared (replaces base exit)
func _handle_body_exited(body: Node2D) -> void:
	for group in unsafe_groups:
		if body.is_in_group(group):
			_unsafe_count -= 1
			## transition from unsafe to safe
			if _unsafe_count <= 0:
				_unsafe_count = 0
				for sig in on_zone_safe:
					game.bus_emit(sig)
			return
