# Flag palette component. Colors a brick grid to match a randomly selected flag pattern.
# Woken by "spawning_wave" signal from UGS, paints bricks once grid is full, then sleeps.
# Loads FlagResource files from a configurable directory at runtime.

extends UniversalComponent

@export var target_group: String = "bricks"
@export var grid_columns: int = 11
@export var grid_rows: int = 12
@export var flags_dir: String = "res://Resources/Flags/"

var _flags: Array = []


func _ready() -> void:
	_load_flags()
	game.spawning_wave.connect(_on_spawning_wave)
	set_process(false)


func _on_spawning_wave(_director, _wave_number: int) -> void:
	set_process(true)


func _process(_delta: float) -> void:
	var bricks = get_tree().get_nodes_in_group(target_group)
	if bricks.size() >= grid_columns * grid_rows:
		_apply_flag(bricks)
		set_process(false)


func _load_flags() -> void:
	_flags.clear()
	var dir = DirAccess.open(flags_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res_path = flags_dir + file_name
			var res = load(res_path)
			if res is FlagResource:
				_flags.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _apply_flag(bricks: Array) -> void:
	if _flags.is_empty():
		return

	# Pick random flag
	var flag: FlagResource = _flags[randi() % _flags.size()]

	# Sort bricks by position (top-to-bottom, left-to-right)
	var sorted: Array = []
	for brick in bricks:
		if is_instance_valid(brick):
			sorted.append(brick)
	sorted.sort_custom(_sort_by_position)

	# Apply colors
	for i in range(mini(sorted.size(), grid_columns * grid_rows)):
		var row = i / grid_columns
		var col = i % grid_columns
		var brick = sorted[i]
		if "use_score_color" in brick:
			brick.use_score_color = false
		brick.modulate = flag.get_color(row, col)
		brick.queue_redraw()


func _sort_by_position(a: Node2D, b: Node2D) -> bool:
	if a.global_position.y < b.global_position.y:
		return true
	if a.global_position.y > b.global_position.y:
		return false
	return a.global_position.x < b.global_position.x