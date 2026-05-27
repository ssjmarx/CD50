## spawns entities along selected edges of the game bounds
class_name EdgeTrapdoor extends CDStageTrapdoor

@export var spawn_scene: PackedScene
@export var spawn_count_equation: String = "3 + wave_number"
@export var edges: Array[CDEnums.Edge] = [CDEnums.Edge.TOP]
@export var jitter: float = 0.0

var _segments: Array[Dictionary] = []
var _total_perimeter: float = 0.0

func _on_initialize() -> void:
	super._on_initialize()
	_build_perimeter()

## builds the continuous perimeter path from selected edges.
func _build_perimeter() -> void:
	var bounds := game.game_bounds
	_segments.clear()
	_total_perimeter = 0.0

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

func _get_spawn_count(wave_number: int) -> int:
	return CDUtilities.evaluate_int(spawn_count_equation, ["wave_number"], [wave_number], "EdgeTrapdoor '%s'" % name)

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

func _get_spawn_scene(_index: int, _total: int) -> PackedScene:
	return spawn_scene
