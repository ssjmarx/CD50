# Tetromino body composed of tile-sized squares. Supports all 7 standard shapes with collision per tile.

extends UniversalBody

enum Shape { I, O, T, S, Z, L, J }

# Shape configuration
@export var shape: Shape = Shape.T
@export var color: Color = Color.CYAN
@export var tile_size: float = 18.0
@export var randomize_shape = false
@export var single_cell: bool = false  # When true, draw one square at origin, ignore shape/offsets

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

# Ghost piece offsets — set by ghost_piece component. Empty = no ghost.
var ghost_offsets: Array[Vector2i] = []

# Disable physics, load shape offsets, and build collision
func _ready() -> void:
	if not single_cell and randomize_shape:
		shape = Shape.values().pick_random()
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if single_cell:
		current_offsets = [Vector2i(0, 0)]
	else:
		current_offsets.assign(SHAPE_OFFSETS[shape])
	
	_build_collision()
	super._ready()

# Draw a filled square for each tile offset, plus ghost outline
func _draw() -> void:
	# Draw filled cells
	for offset in current_offsets:
		var pos: Vector2 = Vector2(offset.x * tile_size, offset.y * tile_size)
		draw_rect(Rect2(pos - Vector2(tile_size / 2.0, tile_size / 2.0), Vector2(tile_size, tile_size)), color)
	
	# Draw ghost outline (unfilled, semi-transparent)
	if ghost_offsets.size() > 0:
		var ghost_color = Color(color, 0.3)
		for offset in ghost_offsets:
			var pos: Vector2 = Vector2(offset.x * tile_size, offset.y * tile_size)
			var half := Vector2(tile_size / 2.0, tile_size / 2.0)
			var rect := Rect2(pos - half, Vector2(tile_size, tile_size))
			draw_rect(rect, ghost_color, false, 1.0)

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
