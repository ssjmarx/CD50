## spawns entities at its own position
class_name PointTrapdoor extends CDStageTrapdoor

@export var spawn_scene: PackedScene
@export var spawn_count_equation: String = "3 + wave_number"
@export var offset_range: Vector2 = Vector2(10, 10)

func _get_spawn_count(wave_number: int) -> int:
	return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "PointTrapdoor '%s'" % name)

func _get_spawn_position(_index: int, _total: int) -> Vector2:
	return global_position + Vector2(
		randf_range(-offset_range.x, offset_range.x),
		randf_range(-offset_range.y, offset_range.y),
	)

func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	return spawn_scene
