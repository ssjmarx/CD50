# Flag palette component. Colors entities in a grid area via modulate from a flag pattern.
# Uses positional physics queries to find bodies at each grid cell — no group polling, no grid size assumptions.
# Fires on a configurable signal from UGS (spawning_wave_complete, piece_settled, etc.).
# Can be pointed to a specific FlagResource or randomly picks one from flags_dir.

extends UniversalComponent2D

# Grid geometry — position this node so the grid covers the target area
@export var columns: int = 10
@export var rows: int = 5
@export var cell_size: Vector2 = Vector2(18, 18)

# Signal configuration — which UGS signal triggers palette application
@export var source_signal: String = "spawning_wave_complete"

# Flag selection — specific resource overrides random directory selection
@export var flag_resource: FlagResource = null
@export var flags_dir: String = "res://Resources/Flags/"

var _flags: Array = []


func _ready() -> void:
	_load_flags()
	if game and game.has_signal(source_signal):
		game.connect(source_signal, _on_signal_fired)
	set_process(false)


func _on_signal_fired(_arg1 = null, _arg2 = null) -> void:
	await get_tree().physics_frame
	_apply_palette()


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


func _apply_palette() -> void:
	var flag := flag_resource
	if flag == null:
		if _flags.is_empty():
			return
		flag = _flags[randi() % _flags.size()]

	var space_state = get_world_2d().direct_space_state

	for row in range(rows):
		for col in range(columns):
			# Tile the flag pattern if grid is larger than the flag
			var flag_row = row % flag.get_row_count()
			var flag_col = col % flag.columns
			var flag_color = flag.get_color(flag_row, flag_col)

			# World position of this cell center
			var x_pos = global_position.x + col * cell_size.x + cell_size.x / 2.0
			var y_pos = global_position.y + row * cell_size.y + cell_size.y / 2.0
			var body = _get_body_at(space_state, Vector2(x_pos, y_pos))

			if body and is_instance_valid(body):
				body.modulate = flag_color
				# If the body has a 'color' property, set it to white so modulate tints cleanly
				if "color" in body:
					body.color = Color.WHITE
				if body.has_method("queue_redraw"):
					body.queue_redraw()


# Get a single physics body at the given position
func _get_body_at(space_state: PhysicsDirectSpaceState2D, pos: Vector2) -> Node2D:
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results = space_state.intersect_point(query)
	for result in results:
		var body = result["collider"]
		if body:
			return body
	return null