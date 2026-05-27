## spawn-safety monitor for trapdoors
class_name SafeZoneMark extends CDMark

@export var unsafe_groups: Array[StringName] = [&"enemies"]

@export_group("Emit Signals")
@export var on_zone_safe: Array[StringName] = [&"zone_safe"]
@export var on_zone_unsafe: Array[StringName] = [&"zone_unsafe"]

var _unsafe_count: int = 0

func _on_body_entered(body: Node2D) -> void:
	for group in unsafe_groups:
		if body.is_in_group(group):
			var was_safe := _unsafe_count == 0
			_unsafe_count += 1
			if was_safe:
				for sig in on_zone_unsafe:
					game.bus_emit(sig, [])
			return

func _on_body_exited(body: Node2D) -> void:
	for group in unsafe_groups:
		if body.is_in_group(group):
			_unsafe_count -= 1
			if _unsafe_count <= 0:
				_unsafe_count = 0
				for sig in on_zone_safe:
					game.bus_emit(sig, [])
			return
