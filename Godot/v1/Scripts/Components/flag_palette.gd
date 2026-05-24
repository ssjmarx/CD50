# Flag palette component. Colors entities in a grid area via modulate from a flag pattern.
# Uses position-based node matching — finds children in the grid area by global_position,
# so it works on all platforms without depending on physics query timing.
# Fires on a configurable signal from UGS (spawning_wave_complete, piece_settled, etc.).
# Uses explicit flag_resources array (web-safe) instead of runtime directory scanning.

extends UniversalComponent2D

# Grid geometry — position this node so the grid covers the target area
@export var columns: int = 10
@export var rows: int = 5
@export var cell_size: Vector2 = Vector2(18, 18)

# Signal configuration — which UGS signal triggers palette application
@export var source_signal: String = "spawning_wave_complete"

# Flag selection — specific resource overrides random selection from flag_resources
@export var flag_resource: FlagResource = null
@export var flag_resources: Array[FlagResource] = []


func _ready() -> void:
	if game and game.has_signal(source_signal):
		game.connect(source_signal, _on_signal_fired)
	set_process(false)


func _on_signal_fired(_arg1 = null, _arg2 = null) -> void:
	await get_tree().physics_frame
	_apply_palette()


func _apply_palette() -> void:
	var flag := flag_resource
	if flag == null:
		if flag_resources.is_empty():
			return
		flag = flag_resources[randi() % flag_resources.size()]

	# Build the grid bounds in world space
	var grid_origin := global_position
	var grid_width := columns * cell_size.x
	var grid_height := rows * cell_size.y

	# Iterate all game children and match by position — no physics queries needed
	for child in game.get_children():
		if not child is Node2D:
			continue
		var node_2d := child as Node2D
		if not is_instance_valid(node_2d):
			continue

		# Check if this node falls within the grid area
		var local_pos := node_2d.global_position - grid_origin
		if local_pos.x < 0.0 or local_pos.y < 0.0:
			continue
		if local_pos.x >= grid_width or local_pos.y >= grid_height:
			continue

		# Determine which grid cell this node occupies
		var col := int(local_pos.x / cell_size.x)
		var row := int(local_pos.y / cell_size.y)
		if col < 0 or col >= columns or row < 0 or row >= rows:
			continue

		# Tile the flag pattern if grid is larger than the flag
		var flag_row := row % flag.get_row_count()
		var flag_col := col % flag.columns
		var flag_color := flag.get_color(flag_row, flag_col)

		node_2d.modulate = flag_color
		# If the body has a 'color' property, set it to white so modulate tints cleanly
		if "color" in node_2d:
			node_2d.color = Color.WHITE
		if node_2d.has_method("queue_redraw"):
			node_2d.queue_redraw()
