# PointTrapdoor
# Spawns entities at its own position with optional random offset range
# Simplest trapdoor — uses equation-based count and single scene

class_name PointTrapdoor extends CDStageTrapdoor

# --- exports ---

# scene to instantiate for each entity
@export var spawn_scene: PackedScene
# equation string for spawn count (e.g. "3 + wave_number")
@export var spawn_count_equation: String = "3 + wave_number"
# maximum random offset from global_position (x, y)
@export var offset_range: Vector2 = Vector2(10, 10)

# --- virtual overrides ---

# evaluate the spawn count equation for this wave
func _get_spawn_count(wave_number: int) -> int:
	return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "PointTrapdoor '%s'" % name)

# return position with random offset within offset_range
func _get_spawn_position(_index: int, _total: int) -> Vector2:
	return global_position + Vector2(
		randf_range(-offset_range.x, offset_range.x),
		randf_range(-offset_range.y, offset_range.y),
	)

# return the single configured spawn scene
func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	return spawn_scene