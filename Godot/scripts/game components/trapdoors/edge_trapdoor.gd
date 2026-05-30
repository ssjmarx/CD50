# EdgeTrapdoor
# Spawns entities evenly distributed along selected edges of the game bounds
# Supports jitter for randomizing positions along the perimeter

class_name EdgeTrapdoor extends CDStageTrapdoor

# --- exports ---

# scene to instantiate for each entity
@export var spawn_scene: PackedScene
# equation string for spawn count (e.g. "3 + wave_number")
@export var spawn_count_equation: String = "3 + wave_number"
# which edges of the game bounds to spawn along
@export var edges: Array[CDEnums.Edge] = [CDEnums.Edge.TOP]
# 0.0 = even spacing, 1.0 = fully random along perimeter
@export var jitter: float = 0.0

# --- state ---

# perimeter segments built from selected edges
var _segments: Array[Dictionary] = []
# total perimeter length across all selected edges
var _total_perimeter: float = 0.0

# --- lifecycle ---

# build perimeter segments after base initialization
func _on_initialize() -> void:
	super._on_initialize()
	_build_perimeter()

# --- perimeter construction ---

# build the continuous perimeter path from selected game bounds edges
func _build_perimeter() -> void:
	var bounds := game.game_bounds
	_segments.clear()
	_total_perimeter = 0.0

	# convert each selected edge to a start/end segment
	for edge: CDEnums.Edge in edges:
		var start: Vector2
		var end: Vector2
		match edge:
			CDEnums.Edge.TOP:
				start = Vector2(bounds.position.x, bounds.position.y)
				end = Vector2(bounds.end.x, bounds.position.y)
			CDEnums.Edge.RIGHT:
				start = Vector2(bounds.end.x, bounds.position.y)
				end = Vector2(bounds.end.x, bounds.end.y)
			CDEnums.Edge.BOTTOM:
				start = Vector2(bounds.end.x, bounds.end.y)
				end = Vector2(bounds.position.x, bounds.end.y)
			CDEnums.Edge.LEFT:
				start = Vector2(bounds.position.x, bounds.end.y)
				end = Vector2(bounds.position.x, bounds.position.y)
		var length := start.distance_to(end)
		_segments.append({start = start, end = end, length = length})
		_total_perimeter += length

# --- virtual overrides ---

# evaluate the spawn count equation for this wave
func _get_spawn_count(wave_number: int) -> int:
	return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "EdgeTrapdoor '%s'" % name)

# calculate world position by walking the perimeter with jitter
func _get_spawn_position(index: int, total: int) -> Vector2:
	# even base position along perimeter
	var even_pos := (index + 0.5) / total * _total_perimeter

	# random position anywhere on perimeter
	var rand_pos := randf() * _total_perimeter

	# lerp between even and random based on jitter
	var actual_pos := lerpf(even_pos, rand_pos, jitter)
	actual_pos = fposmod(actual_pos, _total_perimeter)

	# walk the perimeter to find the world position
	var accumulated := 0.0
	for seg in _segments:
		if actual_pos <= accumulated + seg.length:
			var t: float = (actual_pos - accumulated) / seg.length
			return seg.start.lerp(seg.end, t)
		accumulated += seg.length

	# fallback: end of last segment
	return _segments[-1].end

# return the single configured spawn scene
func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	return spawn_scene
