# Tetromino body composed of tile-sized squares. Supports all 7 standard shapes with collision per tile.

extends UniversalBody

enum Shape { I, O, T, S, Z, L, J }

# Shape configuration
@export var shape: Shape = Shape.T
@export var color: Color = Color.CYAN
@export var tile_size: float = 18.0
@export var randomize_shape = false
@export var single_cell: bool = false  # When true, draw one square at origin, ignore shape/offsets
@export var brick_style: bool = true   # Draw cells as 3D cubes with highlight/shadow edges
@export var color_variation: float = 0.1  # Per-cell random hue/sat variation (0 = none)

# Grid offsets for each shape type (relative to pivot tile)
const SHAPE_OFFSETS: Dictionary = {
	Shape.I: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(2,0)],
	Shape.O: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
	Shape.T: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1)],
	Shape.S: [Vector2i(0,0), Vector2i(-1,0), Vector2i(0,-1), Vector2i(1,-1)],
	Shape.Z: [Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(-1,-1)],
	Shape.L: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(1,-1)],
	Shape.J: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,-1)],
}

var current_offsets: Array[Vector2i] = []

# Per-cell random color offsets for brick variation
var _cell_color_seeds: Array[float] = []

# Ghost piece offsets — set by ghost_piece component. Empty = no ghost.
var ghost_offsets: Array[Vector2i] = []

# Disable physics, load shape offsets, and build collision
func _ready() -> void:
	if not single_cell and randomize_shape:
		shape = Shape.values().pick_random()
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Generate per-cell color variation seeds
	_regenerate_color_seeds(4)
	
	if single_cell:
		current_offsets = [Vector2i(0, 0)]
	else:
		current_offsets.assign(SHAPE_OFFSETS[shape])
	
	_build_collision()
	super._ready()

# Draw a filled square for each tile offset, plus ghost outline
func _draw() -> void:
	# Draw filled cells
	for i in current_offsets.size():
		var offset = current_offsets[i]
		var pos: Vector2 = Vector2(offset.x * tile_size, offset.y * tile_size)
		var half := Vector2(tile_size / 2.0, tile_size / 2.0)
		var rect := Rect2(pos - half, Vector2(tile_size, tile_size))
		var cell_color = _get_cell_color(i)
		
		if brick_style:
			_draw_brick(pos, half, cell_color)
		else:
			draw_rect(rect, cell_color)
	
	# Draw ghost outline (unfilled, semi-transparent)
	if ghost_offsets.size() > 0:
		var ghost_color = Color(color, 0.3)
		for offset in ghost_offsets:
			var pos: Vector2 = Vector2(offset.x * tile_size, offset.y * tile_size)
			var half := Vector2(tile_size / 2.0, tile_size / 2.0)
			var rect := Rect2(pos - half, Vector2(tile_size, tile_size))
			draw_rect(rect, ghost_color, false, 2.0)

# Generate random color seeds for each cell
func _regenerate_color_seeds(count: int) -> void:
	_cell_color_seeds.clear()
	for i in count:
		_cell_color_seeds.append(randf())

# Get the varied color for a specific cell
func _get_cell_color(index: int) -> Color:
	if not brick_style or color_variation <= 0.0:
		return color
	var seed_val = _cell_color_seeds[index % _cell_color_seeds.size()] if _cell_color_seeds.size() > 0 else 0.5
	var h = color.h + (seed_val - 0.5) * color_variation
	var s = color.s
	var v = color.v + (seed_val - 0.5) * color_variation * 0.5
	return Color.from_hsv(h, s, v)

# Draw a 3D brick-style cell with highlight and shadow edges
func _draw_brick(pos: Vector2, half: Vector2, cell_color: Color) -> void:
	var rect := Rect2(pos - half, Vector2(tile_size, tile_size))
	
	# Main fill
	draw_rect(rect, cell_color)
	
	# Highlight (top + left edges)
	var highlight = Color(cell_color.r + 0.2, cell_color.g + 0.2, cell_color.b + 0.2)
	var edge_width = maxf(2.0, tile_size * 0.12)
	# Top edge
	draw_rect(Rect2(pos - half, Vector2(tile_size, edge_width)), highlight)
	# Left edge
	draw_rect(Rect2(pos - half, Vector2(edge_width, tile_size)), highlight)
	
	# Shadow (bottom + right edges)
	var shadow = Color(cell_color.r - 0.25, cell_color.g - 0.25, cell_color.b - 0.25)
	# Bottom edge
	draw_rect(Rect2(pos.x - half.x, pos.y + half.y - edge_width, tile_size, edge_width), shadow)
	# Right edge
	draw_rect(Rect2(pos.x + half.x - edge_width, pos.y - half.y, edge_width, tile_size), shadow)

# Update the tile offsets (e.g., after rotation) and rebuild collision + redraw
func update_offsets(new_offsets: Array[Vector2i]) -> void:
	current_offsets = new_offsets
	_rebuild_collision()
	queue_redraw()

# Create one CollisionShape2D per tile positioned at each grid offset
func _build_collision() -> void:
	for offset in current_offsets:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		shape_node.shape = rect
		shape_node.position = Vector2(offset.x * tile_size, offset.y * tile_size)
		add_child(shape_node)

# Remove existing collision shapes and recreate at current offset positions
func _rebuild_collision() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	for offset in current_offsets:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(tile_size, tile_size)
		shape_node.shape = rect
		shape_node.position = Vector2(offset.x * tile_size, offset.y * tile_size)
		add_child(shape_node)
