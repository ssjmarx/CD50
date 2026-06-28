## SafeZoneMark
## Monitors whether the zone is clear of unsafe bodies for trapdoor spawning
## Transitions between safe/unsafe states and emits on each transition
##
## Emit behavior: REPLACES base enter/exit. The base on_entered / on_exited game-bus
## signals and the entered_body_key / exited_body_key blackboard writes DO NOT fire —
## the overrides below do not call super and do not use _emit_enter/_emit_exit. Only this
## mark's own on_zone_unsafe / on_zone_safe signals fire (on state transitions).

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

## --- body detection ---

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
